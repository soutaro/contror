module Contror
  module ANF
    module AST
      module Stmt
        class Base
          attr_reader :node
          attr_reader :dest

          def initialize(dest:, node:)
            @dest = dest
            @node = node
          end

          def each_sub_stmt(recursively: false, &block)
          end
        end

        class Block < Base
          attr_reader :stmts

          def initialize(dest:, stmts:, node:)
            @stmts = stmts
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            stmts.each do |stmt|
              yield stmt
              stmt.each_sub_stmt(recursively: recursively, &block) if recursively
            end
          end
        end

        class Value < Base
          attr_reader :value

          def initialize(dest:, value:, node:)
            @value = value
            super(dest: dest, node: node)
          end
        end

        class Assign < Base
          attr_reader :lhs
          attr_reader :rhs

          def initialize(dest:, lhs:, rhs:, node:)
            @lhs = lhs
            @rhs = rhs
            super(dest: dest, node: node)
          end
        end

        class Call < Base
          class Block
            attr_reader :params
            attr_reader :body

            def initialize(params:, body:)
              @params = params
              @body = body
            end
          end

          attr_reader :receiver
          attr_reader :name
          attr_reader :args
          attr_reader :block

          def initialize(dest:, receiver:, name:, args:, block:, node:)
            @receiver = receiver
            @name = name
            @args = args
            @block = block
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if self.block
              self.block.params.each do |param|
                if param[2]
                  yield param[2]
                  param[2].each_sub_stmt(recursively: true, &block) if recursively
                end
              end
              if self.block.body
                yield self.block.body
                self.block.body.each_sub_stmt(recursively: true, &block) if recursively
              end
            end
          end
        end

        class If < Base
          attr_reader :condition
          attr_reader :then_clause
          attr_reader :else_clause

          def initialize(dest:, condition:, then_clause:, else_clause:, node:)
            @condition = condition
            @then_clause = then_clause
            @else_clause = else_clause
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            yield condition
            condition.each_sub_stmt(recursively: true, &block) if recursively

            if then_clause
              yield then_clause
              then_clause.each_sub_stmt(recursively: true, &block) if recursively
            end

            if else_clause
              yield else_clause
              else_clause.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Loop < Base
          attr_reader :body

          def initialize(dest:, body:, node:)
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class For < Base
          attr_reader :var
          attr_reader :collection
          attr_reader :body

          def initialize(dest:, var:, collection:, body:, node:)
            @var = var
            @collection = collection
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        # Jump statement includes return, break, next, and retry
        class Jump < Base
          attr_reader :type
          attr_reader :args

          def initialize(dest:, type:, args:, node:)
            @type = type
            @args = args
            super(dest: dest, node: node)
          end
        end

        class ConstantAssign < Base
          attr_reader :prefix
          attr_reader :name
          attr_reader :value

          def initialize(dest:, prefix:, name:, value:, node:)
            @prefix = prefix
            @name = name
            @value = value
            super(dest: dest, node: node)
          end
        end

        class Constant < Base
          attr_reader :prefix
          attr_reader :name

          def initialize(dest:, prefix:, name:, node:)
            @prefix = prefix
            @name = name
            super(dest: dest, node: node)
          end
        end

        class Yield < Base
          attr_reader :args

          def initialize(dest:, args:, node:)
            @args = args
            super(dest: dest, node: node)
          end
        end

        class Array < Base
          attr_reader :elements

          def initialize(dest:, elements:, node:)
            @elements = elements
            super(dest: dest, node: node)
          end
        end

        class Hash < Base
          class Pair
            attr_reader :key
            attr_reader :value

            def initialize(key:, value:)
              @key = key
              @value = value
            end
          end

          attr_reader :pairs
          attr_reader :splat

          def initialize(dest:, pairs:, splat:, node:)
            @pairs = pairs
            @splat = splat
            super(dest: dest, node: node)
          end
        end

        class Dstr < Base
          attr_reader :components

          def initialize(dest:, components:, node:)
            @components = components
            super(dest: dest, node: node)
          end
        end

        class Xstr < Base
          attr_reader :components

          def initialize(dest:, components:, node:)
            @components = components
            super(dest: dest, node: node)
          end
        end

        class Dsym < Base
          attr_reader :components

          def initialize(dest:, components:, node:)
            @components = components
            super(dest: dest, node: node)
          end
        end

        class MAssign < Base
          attr_reader :vars
          attr_reader :rhs

          def initialize(dest:, vars:, rhs:, node:)
            @vars = vars
            @rhs = rhs
            super(dest: dest, node: node)
          end
        end

        class Rescue < Base
          class Clause
            attr_reader :class_stmt
            attr_reader :var
            attr_reader :body

            def initialize(class_stmt:, var:, body:)
              @class_stmt = class_stmt
              @var = var
              @body = body
            end
          end

          attr_reader :body
          attr_reader :rescues

          def initialize(dest:, body:, rescues:, node:)
            @body = body
            @rescues = rescues
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            yield body if body

            rescues.each do |r|
              if r.class_stmt
                yield r.class_stmt
                r.class_stmt.each_sub_stmt(recursively: recursively, &block) if recursively
              end

              if r.body
                yield r.body
                r.body.each_sub_stmt(recursively: recursively, &block) if recursively
              end
            end
          end
        end

        class Ensure < Base
          attr_reader :ensured
          attr_reader :ensuring

          def initialize(dest:, ensured:, ensuring:, node:)
            @ensured = ensured
            @ensuring = ensuring
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if ensured
              yield ensured
              ensured.each_sub_stmt(recursively: true, &block) if recursively
            end
            if ensuring
              yield ensuring
              ensuring.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Class < Base
          attr_reader :name
          attr_reader :super_class
          attr_reader :body

          def initialize(dest:, name:, super_class:, body:, node:)
            @name = name
            @super_class = super_class
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Module < Base
          attr_reader :name
          attr_reader :body

          def initialize(dest:, name:, body:, node:)
            @name = name
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class SingletonClass < Base
          attr_reader :object
          attr_reader :body

          def initialize(dest:, object:, body:, node:)
            @object = object
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Def < Base
          attr_reader :object
          attr_reader :name
          attr_reader :params
          attr_reader :body

          def initialize(dest:, object:, name:, params:, body:, node:)
            @object = object
            @name = name
            @params = params
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            params.each do |p|
              if p[2]
                yield p[2]
                p[2].each_sub_stmt(recursively: true, &block) if recursively
              end
            end

            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Lambda < Base
          attr_reader :params
          attr_reader :body

          def initialize(dest:, params:, body:, node:)
            @params = params
            @body = body
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            params.each do |p|
              if p[2]
                yield p[2]
                p[2].each_sub_stmt(recursively: true, &block) if recursively
              end
            end

            if body
              yield body
              body.each_sub_stmt(recursively: true, &block) if recursively
            end
          end
        end

        class Case < Base
          class When
            attr_reader :pattern
            attr_reader :body

            def initialize(pattern:, body:)
              @pattern = pattern
              @body = body
            end
          end

          attr_reader :condition
          attr_reader :whens

          def initialize(dest:, condition:, whens:, node:)
            @condition = condition
            @whens = whens
            super(dest: dest, node: node)
          end

          def each_sub_stmt(recursively: false, &block)
            whens.each do |w|
              if w.pattern
                yield w.pattern
                w.pattern.each_sub_stmt(recursively: true, &block) if recursively
              end
              if w.body
                yield w.body
                w.body.each_sub_stmt(recursively: true, &block) if recursively
              end
            end
          end
        end

        class ZSuper < Base
        end

        class Super < Base
          attr_reader :args

          def initialize(dest:, args:, node:)
            @args = args
            super(dest: dest, node: node)
          end
        end

        class Regexp < Base
          attr_reader :content
          attr_reader :option

          def initialize(dest:, content:, option:, node:)
            @content = content
            @option = option
            super(dest: dest, node: node)
          end
        end

        class MatchWithLasgn < Base
          attr_reader :lhs
          attr_reader :rhs

          def initialize(dest:, lhs:, rhs:, node:)
            @lhs = lhs
            @rhs = rhs
            super(dest: dest, node: node)
          end
        end

        class Range < Base
          attr_reader :begin
          attr_reader :end
          attr_reader :type

          def initialize(dest:, beginv:, endv:, type:, node:)
            @begin = beginv
            @end = endv
            @type = type
            super(dest: dest, node: node)
          end
        end
      end
    end
  end
end
