module Contror
  module ANF
    class Translator
      attr_reader :count

      def initialize()
        @fresh_var_id = 0
      end

      # Translate given node to Stmt
      def translate(node:)
        maybe_block(translate0(node: node, stmts: []), node: node)
      end

      def maybe_block(stmts, node:)
        if stmts.count > 1
          AST::Stmt::Block.new(stmts: stmts, node: node)
        else
          stmts.first
        end
      end

      def translate0(node:, var: nil, stmts: [])
        # p node

        if node.type == :begin
          node.children[0, node.children.size - 1].each do |child|
            translate0(node: child, var: nil, stmts: stmts)
          end

          translate0(node: node.children.last, var: var, stmts: stmts)
        else
          case node.type
          when :lvasgn, :ivasgn, :gvasgn, :cvasgn
            v = translate_var(node)
            stmts << AST::Stmt::Assign.new(var: v,
                                           expr: translate_expr(node.children[1], stmts: stmts),
                                           node: node)

            if var
              stmts << AST::Stmt::Assign.new(var: var, expr: AST::Expr::Var.new(var: v, node: nil))
            end

          when :casgn
            if (prefix_node = node.children[0])
              prefix = normalized_expr(prefix_node, stmts: stmts)
            end

            stmts << AST::Stmt::ConstantAssign.new(prefix: prefix,
                                                   name: node.children[1],
                                                   expr: translate_expr(node.children[2], stmts: stmts),
                                                   node: node)

            if var
              stmts << AST::Stmt::Assign.new(var: var, expr: AST::Expr::Var.new(var: v, node: nil))
            end

          when :if
            condition = normalized_expr(node.children[0], stmts: stmts)
            if (then_node = node.children[1])
              then_claus = maybe_block(translate0(node: then_node, var: var, stmts: []), node: then_node)
            end
            if (else_node = node.children[2])
              else_clause = maybe_block(translate0(node: else_node, var: var, stmts: []), node: else_node)
            end

            stmts << AST::Stmt::If.new(condition: condition, then_clause: then_claus, else_clause: else_clause, node: node)

          when :while
            translate_while(node, break_var: var, stmts: stmts)

          else
            expr = translate_expr(node, stmts: stmts)

            if var
              stmts << AST::Stmt::Assign.new(var: var, expr: expr, node: node)
            else
              stmts << AST::Stmt::Expr.new(expr: expr, node: node)
            end
          end
        end

        stmts
      end

      def translate_while(node, break_var:, stmts:)
        condition = maybe_block(translate0(node: node.children[0], var: nil, stmts: []), node: node.children[0])

        if (body_node = node.children[1])
          body = maybe_block(translate0(node: body_node, var: nil, stmts: []), node: body_node)
        end

        stmts << AST::Stmt::While.new(condition: condition, body: body, break_var: break_var, node: node)
      end

      def translate_expr(node, stmts:)
        if value_node?(node)
          case node.type
          when :lvar, :cvar, :ivar, :gvar
            AST::Expr::Var.new(var: translate_var(node), node: node)
          else
            AST::Expr::Value.new(node: node)
          end
        else
          case node.type
          when :send
            receiver = if (receiver_node = node.children[0])
                         normalized_expr(receiver_node, stmts: stmts)
                       end

            args = []

            node.children.drop(2).each do |a|
              args << normalized_expr(a, stmts: stmts)
            end

            AST::Expr::Call.new(receiver: receiver, name: node.children[1], args: args, block: nil, node: node)

          when :if
            a = fresh_var
            stmts << maybe_block(translate0(node: node, var: a, stmts: []), node: node)
            AST::Expr::Var.new(var: a, node: nil)

          when :while
            a = fresh_var
            translate_while(node, break_var: a, stmts: stmts)
            AST::Expr::Var.new(var: a, node: nil)

          when :const
            if (prefix_node = node.children[0])
              prefix = normalized_expr(prefix_node, stmts: stmts)
            end

            AST::Expr::Constant.new(prefix: prefix, name: node.children[1], node: node)

          else
            p unknown_node: node
          end
        end
      end

      def normalized_expr(node, stmts:)
        if value_node?(node)
          translate_expr(node, stmts: stmts)
        else
          a = fresh_var
          expr = translate_expr(node, stmts: stmts)

          assign = AST::Stmt::Assign.new(var: a, expr: expr, node: node)
          stmts << assign

          AST::Expr::Var.new(var: a, node: nil)
        end
      end

      def value_node?(node)
        case node.type
        when :int, :lvar, :ivar, :gvar, :cvar
          true
        when :true, :false, :nil
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
