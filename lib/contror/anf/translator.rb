module Contror
  module ANF
    using Contror::ObjectTry

    class Translator
      attr_reader :blocks

      def initialize()
        @fresh_var_id = 0
        @blocks = []
      end

      # Translate given node to Stmt
      def translate(node:)
        with_new_block node do
          translate0(node)
        end
      end

      def with_new_block(node)
        @blocks << []

        yield

        block = @blocks.pop

        case block.size
        when 0
          nil
        when 1
          block.first
        else
          AST::Stmt::Block.new(dest: fresh_var, stmts: block, node: node)
        end
      end

      def current_block
        @blocks.last
      end

      def push_stmt(stmt)
        current_block.push stmt
        stmt
      end

      def normalize_node(node)
        if value_node?(node)
          case node.type
          when :ivar, :lvar, :gvar, :cvar
            translate_var(node)
          else
            node
          end
        else
          translate0(node).dest
        end
      end

      def translate0(node)
        case node.type
        when :begin
          block = with_new_block node do
            node.children.each do |child|
              translate0(child)
            end
          end

          push_stmt block

        when :if
          condition = normalize_node(node.children[0])
          then_clause = node.children[1].try {|child| with_new_block(child) { translate0(child) } }
          else_clause = node.children[2].try {|child| with_new_block(child) { translate0(child) } }

          push_stmt AST::Stmt::If.new(dest: fresh_var,
                                      condition: condition,
                                      then_clause: then_clause,
                                      else_clause: else_clause,
                                      node: node)

        when :send
          translate_call node, block: nil

        when :csend
          translate_call node, block: nil

        when :block
          params = translate_params node.children[1]
          body = node.children[2].try {|block_node| translate(node: block_node) }

          case node.children[0].type
          when :send, :csend
            translate_call node.children[0], block: AST::Stmt::Call::Block.new(params: params, body: body)
          when :lambda
            push_stmt AST::Stmt::Lambda.new(dest: fresh_var,
                                            params: params,
                                            body: body,
                                            node: node)
          else
            raise "unknown block child: #{node.children[0].type}"
          end

        when :dstr
          components = []
          node.children.each do |child|
            components << normalize_node(child)
          end

          push_stmt AST::Stmt::Dstr.new(dest: fresh_var, components: components, node: node)

        when :dsym
          components = []
          node.children.each do |child|
            components << normalize_node(child)
          end

          push_stmt AST::Stmt::Dsym.new(dest: fresh_var, components: components, node: node)

        when :xstr
          components = []
          node.children.each do |child|
            components << normalize_node(child)
          end

          push_stmt AST::Stmt::Xstr.new(dest: fresh_var, components: components, node: node)

        when :for
          var = translate_var(node.children[0])
          collection = normalize_node(node.children[1])
          body = node.children[2].try {|body_node| translate(node: body_node) }

          push_stmt AST::Stmt::For.new(dest: fresh_var, var: var, collection: collection, body: body, node: node)

        when :while
          loop = with_new_block node do
            cond = normalize_node(node.children[0])

            break_stmt = AST::Stmt::Jump.new(dest: fresh_var, type: :break, args: [], node: nil)

            push_stmt AST::Stmt::If.new(dest: fresh_var,
                                        condition: cond,
                                        then_clause: nil,
                                        else_clause: break_stmt,
                                        node: node.children[0])

            node.children[1].try {|body| translate0(body) }
          end

          push_stmt AST::Stmt::Loop.new(dest: fresh_var, body: loop, node: node)

        when :until
          loop = with_new_block node do
            cond = normalize_node(node.children[0])

            break_stmt = AST::Stmt::Jump.new(dest: fresh_var, type: :break, args: [], node: nil)

            push_stmt AST::Stmt::If.new(dest: fresh_var,
                                        condition: cond,
                                        then_clause: break_stmt,
                                        else_clause: nil,
                                        node: node.children[0])

            node.children[1].try {|body| translate0(body) }
          end

          push_stmt AST::Stmt::Loop.new(dest: fresh_var, body: loop, node: node)

        when :array
          elements = []

          node.children.each do |child|
            elements << translate_arg(child)
          end

          push_stmt AST::Stmt::Array.new(dest: fresh_var, elements: elements, node: node)

        when :hash
          pairs = []

          splat = nil

          node.children.each do |pair|
            case pair.type
            when :pair
              key = normalize_node(pair.children[0])
              value = normalize_node(pair.children[1])
              pairs << AST::Stmt::Hash::Pair.new(key: key, value: value)
            when :kwsplat
              splat = normalize_node(pair.children[0])
            else
              raise "unknown hash element: #{pair.type}"
            end
          end

          push_stmt AST::Stmt::Hash.new(dest: fresh_var, pairs: pairs, splat: splat, node: node)

        when :casgn
          prefix = node.children[0].try {|prefix| normalize_node(prefix) }
          value = normalize_node(node.children[2])

          push_stmt AST::Stmt::ConstantAssign.new(dest: fresh_var,
                                                  prefix: prefix,
                                                  name: node.children[1],
                                                  value: value,
                                                  node: node)
        when :const
          prefix = node.children[0].try {|prefix| normalize_node(prefix) }

          push_stmt AST::Stmt::Constant.new(dest: fresh_var,
                                            prefix: prefix,
                                            name: node.children[1],
                                            node: node)

        when :ivar, :lvar, :gvar, :cvar
          var = translate_var(node)
          push_stmt AST::Stmt::Value.new(dest: fresh_var, value: var, node: node)

        when :lvasgn, :ivasgn, :gvasgn, :cvasgn
          lhs_var = translate_var(node)
          rhs = normalize_node(node.children[1])
          push_stmt AST::Stmt::Assign.new(dest: fresh_var, lhs: lhs_var, rhs: rhs, node: node)

        when :retry, :next
          push_stmt AST::Stmt::Jump.new(dest: fresh_var, type: node.type, args: nil, node: node)

        when :break, :return
          args = []
          node.children.each do |arg|
            args << translate_arg(arg)
          end
          push_stmt AST::Stmt::Jump.new(dest: fresh_var, type: node.type, args: args, node: node)

        when :yield
          args = []
          node.children.each do |arg|
            args << translate_arg(arg)
          end
          push_stmt AST::Stmt::Yield.new(dest: fresh_var, args: args, node: node)

        when :class
          name = normalize_node(node.children[0])
          super_class = node.children[1].try {|super_node| normalize_node(super_node) }
          body = node.children[2].try {|body_node| translate(node: body_node) }

          push_stmt AST::Stmt::Class.new(dest: fresh_var, name: name, super_class: super_class, body: body, node: node)

        when :module
          name = normalize_node(node.children[0])
          body = node.children[1].try {|body_node| translate(node: body_node) }

          push_stmt AST::Stmt::Module.new(dest: fresh_var, name: name, body: body, node: node)

        when :sclass
          object = normalize_node(node.children[0])
          body = node.children[1].try {|body_node| translate(node: body_node) }

          push_stmt AST::Stmt::SingletonClass.new(dest: fresh_var, object: object, body: body, node: node)

        when :def, :defs
          case node.type
          when :def
            object_node = nil
            name = node.children[0]
            args_node = node.children[1]
            body_node = node.children[2]
          when :defs
            object_node = node.children[0]
            name = node.children[1]
            args_node = node.children[2]
            body_node = node.children[3]
          end

          object = object_node.try {|n| normalize_node(n) }
          params = translate_params(args_node)
          body = body_node.try {|n| translate(node: n) }

          push_stmt AST::Stmt::Def.new(dest: fresh_var, object: object, name: name, params: params, body: body, node: node)

        when :and
          lhs = normalize_node(node.children[0])
          rhs = translate(node: node.children[1])

          push_stmt AST::Stmt::If.new(dest: fresh_var, condition: lhs, then_clause: rhs, else_clause: nil, node: node)

        when :or
          lhs = normalize_node(node.children[0])
          rhs = translate(node: node.children[1])

          push_stmt AST::Stmt::If.new(dest: fresh_var, condition: lhs, then_clause: nil, else_clause: rhs, node: node)

        when :masgn
          vars = []
          node.children[0].children.each do |asgn|
            if asgn.type == :splat
              v = asgn.children.first.try {|v| translate_var(v) }
              vars << AST::Variable::Splat.new(var: v)
            else
              vars << translate_var(asgn)
            end
          end

          rhs = normalize_node(node.children[1])

          push_stmt AST::Stmt::MAssign.new(dest: fresh_var, vars: vars, rhs: rhs, node: node)

        when :kwbegin
          translate0(node.children.first)

        when :rescue
          body = node.children[0].try {|body_node| translate(node: body_node) }

          rescues = []
          node.children.drop(1).each do |res|
            if res
              class_stmt = res.children[0].try {|a| translate(node: a) }
              var = res.children[1].try {|x| translate_var(x) }
              rescue_body = res.children[2].try {|body_node| translate(node: body_node) }

              rescues << AST::Stmt::Rescue::Clause.new(class_stmt: class_stmt, var: var, body: rescue_body)
            end
          end

          push_stmt AST::Stmt::Rescue.new(dest: fresh_var, body: body, rescues: rescues, node: node)

        when :ensure
          ensured = node.children[0].try {|body_node| translate(node: body_node) }
          ensuring = node.children[1].try {|body_node| translate(node: body_node)}

          push_stmt AST::Stmt::Ensure.new(dest: fresh_var, ensured: ensured, ensuring: ensuring, node: node)

        when :case
          condition = node.children[0].try {|cond_node| normalize_node(cond_node) }

          whens = []
          node.children.drop(1).compact.each do |when_node|
            if when_node.type == :when
              pattern = translate(node: when_node.children[0])
              body = when_node.children[1].try {|body_node| translate(node: body_node) }
              whens << AST::Stmt::Case::When.new(pattern: pattern, body: body)
            else
              body = translate(node: when_node)
              whens << AST::Stmt::Case::When.new(pattern: nil, body: body)
            end
          end

          push_stmt AST::Stmt::Case.new(dest: fresh_var, condition: condition, whens: whens, node: node)

        when :zsuper
          push_stmt AST::Stmt::ZSuper.new(dest: fresh_var, node: node)

        when :super
          args = []
          node.children.each do |arg|
            args << translate_arg(arg)
          end

          push_stmt AST::Stmt::Super.new(dest: fresh_var, args: args, node: node)

        when :regexp
          content = []
          option = nil

          node.children.each do |child|
            if child.type == :regopt
              option = child.children
            else
              content << normalize_node(child)
            end
          end

          push_stmt AST::Stmt::Regexp.new(dest: fresh_var, content: content, option: option, node: node)

        when :erange, :irange
          type = node.type == :erange ? :exclusive : :inclusive
          beginv = node.children[0].try {|n| normalize_node(n) }
          endv = node.children[1].try {|n| normalize_node(n) }

          push_stmt AST::Stmt::Range.new(dest: fresh_var, beginv: beginv, endv: endv, type: type, node: node)

        when :or_asgn
          lhs = node.children[0]
          rhs = node.children[1]

          case lhs.type
          when :lvasgn, :ivasgn, :gvasgn, :cvasgn
            var = translate_var(lhs)
            assignment = with_new_block node do
              rhs_var = normalize_node(rhs)
              push_stmt AST::Stmt::Assign.new(dest: fresh_var, lhs: var, rhs: rhs_var, node: node)
            end

            push_stmt AST::Stmt::If.new(dest: fresh_var, condition: var, then_clause: nil, else_clause: assignment, node: node)

          when :send
            test = normalize_node(lhs)
            assignment = with_new_block node do
              receiver = lhs.children[0].try {|r| normalize_node(r) }
              setter = :"#{lhs.children[1]}="
              args = normalize_node(rhs)

              push_stmt AST::Stmt::Call.new(dest: fresh_var, receiver: receiver, name: setter, args: [args], block: nil, node: node)
            end

            push_stmt AST::Stmt::If.new(dest: fresh_var, condition: test, then_clause: nil, else_clause: assignment, node: node)

          else
            p node
            raise "#{lhs.type}"
          end

        when :op_asgn
          lhs = node.children[0]
          method = node.children[1]
          rhs = node.children[2]

          case lhs.type
          when :lvasgn, :ivasgn, :gvasgn, :cvasgn
            var = translate_var(lhs)

            call_dest = fresh_var
            push_stmt AST::Stmt::Call.new(dest: call_dest, receiver: var, name: method, args: [normalize_node(rhs)], block: nil, node: node)
            push_stmt AST::Stmt::Assign.new(dest: fresh_var, lhs: var, rhs: call_dest, node: node)

          when :send
            updated_value = fresh_var

            old_var = normalize_node(lhs)
            args = normalize_node(rhs)
            push_stmt AST::Stmt::Call.new(dest: updated_value, receiver: old_var, name: method, args: [args], block: nil, node: node)

            receiver = lhs.children[0].try {|r| normalize_node(r) }
            setter = :"#{lhs.children[1]}="
            push_stmt AST::Stmt::Call.new(dest: fresh_var, receiver: receiver, name: setter, args: [updated_value], block: nil, node: node)

          else
            p node
            raise "#{lhs.type}"
          end

        when :match_with_lvasgn
          lhs = normalize_node node.children[0]
          rhs = normalize_node node.children[1]

          push_stmt AST::Stmt::MatchWithLasgn.new(dest: fresh_var, lhs: lhs, rhs: rhs, node: node)

        when :redo
          push_stmt AST::Stmt::Jump.new(dest: fresh_var, type: :redo, args: nil, node: node)

        when :splat
          var = normalize_node node.children[0]
          splat_var = AST::Variable::Splat.new(var: var)
          push_stmt AST::Stmt::Value.new(dest: fresh_var, value: splat_var, node: node)

        else
          if value_node?(node)
            push_stmt AST::Stmt::Value.new(dest: fresh_var, value: node, node: node)
          else
            p unknown_node: node
            raise "unknown_node #{node.type}"
          end
        end
      end

      def translate_arg(arg)
        case arg.type
        when :block_pass
          var = normalize_node(arg.children[0])
          AST::Variable::BlockPass.new(var: var)
        when :splat
          var = normalize_node(arg.children[0])
          AST::Variable::Splat.new(var: var)
        else
          normalize_node(arg)
        end
      end

      def translate_call(node, block:)
        receiver = node.children[0].try {|recv| normalize_node(recv) }
        name = node.children[1]

        case node.type
        when :send
          args = []
          node.children.drop(2).each do |arg|
            args << translate_arg(arg)
          end

          push_stmt AST::Stmt::Call.new(dest: fresh_var,
                                        receiver: receiver,
                                        name: name,
                                        args: args,
                                        block: block,
                                        node: node)
        when :csend
          then_block = with_new_block node do
            args = []
            node.children.drop(2).each do |arg|
              args << translate_arg(arg)
            end

            push_stmt AST::Stmt::Call.new(dest: fresh_var,
                                          receiver: receiver,
                                          name: name,
                                          args: args,
                                          block: block,
                                          node: node)
          end



          push_stmt AST::Stmt::If.new(dest: fresh_var,
                                      condition: receiver,
                                      then_clause: then_block,
                                      else_clause: nil,
                                      node: node)
        end
      end

      def translate_params(args_node)
        args_node.children.map do |arg_node|
          arg_name = arg_node.children[0]

          case arg_node.type
          when :optarg, :kwoptarg
            stmt = translate(node: arg_node.children[1])
            [arg_node.type, arg_name, stmt]
          else
            [arg_node.type, arg_name]
          end
        end
      end

      def value_node?(node)
        case node.type
        when :ivar, :lvar, :gvar, :cvar
          true
        when :true, :false
          true
        when :float, :str, :sym, :int, :complex, :rational
          true
        when :self, :nil
          true
        when :cbase
          true
        when :nth_ref, :defined?, :alias, :back_ref
          true
        else
          false
        end
      end

      def fresh_var
        @fresh_var_id += 1
        AST::Variable::Pseud.new(id: @fresh_var_id)
      end

      def translate_var(node)
        klass = case node.type
                when :lvasgn, :lvar
                  AST::Variable::Local
                when :ivasgn, :ivar
                  AST::Variable::Instance
                when :gvasgn, :gvar
                  AST::Variable::Global
                when :cvasgn, :cvar
                  AST::Variable::Class
                else
                  p unknown_variable: node
                end

        klass.new(name: node.children[0])
      end
    end
  end
end
