module Contror
  module ANF
    module AST
      module Stmt
        class Base
          attr_reader :node

          def initialize(node:)
            @node = node
          end
        end

        class Block < Base
          attr_reader :stmts

          def initialize(stmts:, node:)
            @stmts = stmts
            super(node: node)
          end
        end

        class Expr < Base
          attr_reader :expr

          def initialize(expr:, node:)
            @expr = expr
            super(node: node)
          end
        end

        class Assign < Base
          attr_reader :var
          attr_reader :expr

          def initialize(var:, expr:, node:)
            @var = var
            @expr = expr
            super(node: node)
          end
        end

        class If < Base
          attr_reader :condition
          attr_reader :then_clause
          attr_reader :else_clause

          def initialize(condition:, then_clause:, else_clause:, node:)
            @condition = condition
            @then_clause = then_clause
            @else_clause = else_clause
            super(node: node)
          end
        end

        class While < Base
          attr_reader :condition
          attr_reader :body
          attr_reader :break_var

          def initialize(condition:, body:, break_var:, node:)
            @condition = condition
            @body = body
            @break_var = break_var
            super(node: node)
          end
        end

        # Jump statement includes return, break, next, and retry
        class Jump < Base
          attr_reader :type
          attr_reader :args

          def initialize(type:, args:, node:)
            @type = type
            @args = args
            super(node: node)
          end
        end

        class ConstantAssign < Base
          attr_reader :prefix
          attr_reader :name
          attr_reader :expr

          def initialize(prefix:, name:, expr:, node:)
            @prefix = prefix
            @name = name
            @expr = expr
            super(node: node)
          end
        end

        class Def < Base
          attr_reader :object
          attr_reader :name
          attr_reader :params
          attr_reader :body

          def initialize(object:, name:, params:, body:, node:)
            @object = object
            @name = name
            @params = params
            @body = body
            super(node: node)
          end
        end
      end

      module Expr
        class Base
          attr_reader :node

          def initialize(node:)
            @node = node
          end
        end

        class Call < Base
          attr_reader :receiver
          attr_reader :name
          attr_reader :args
          attr_reader :block

          def initialize(receiver:, name:, args:, block:, node:)
            @receiver = receiver
            @name = name
            @args = args
            @block = block
            super(node: node)
          end
        end

        class Var < Base
          attr_reader :var

          def initialize(var:, node:)
            @var = var
            super(node: node)
          end
        end

        class Yield < Base
          attr_reader :args

          def initialize(args:, node:)
            @args = args
            super(node: node)
          end
        end

        class Value < Base; end

        class Constant < Base
          attr_reader :prefix
          attr_reader :name

          def initialize(prefix:, name:, node:)
            @prefix = prefix
            @name = name
            super(node: node)
          end
        end

        class Array < Base
          attr_reader :elements

          def initialize(elements:, node:)
            @elements = elements
            super(node: node)
          end
        end
      end

      module Variable
        class Base
          def eql?(other)
            self == other
          end
        end

        module NamedVariable
          def ==(other)
            other.is_a?(self.class) && name == other.name
          end

          def hash
            self.class.hash ^ name.hash
          end
        end

        class Local < Base
          include NamedVariable

          attr_reader :name

          def initialize(name:)
            @name = name
            super()
          end
        end

        class Instance < Base
          include NamedVariable

          attr_reader :name

          def initialize(name:)
            @name = name
            super()
          end
        end

        class Class < Base
          include NamedVariable

          attr_reader :name

          def initialize(name:)
            @name = name
            super()
          end
        end

        class Global < Base
          include NamedVariable

          attr_reader :name

          def initialize(name:)
            @name = name
            super()
          end
        end

        class Pseud < Base
          attr_reader :id

          def initialize(id:)
            @id = id
            super()
          end

          def ==(other)
            other.is_a?(self.class) && id == other.id
          end

          def hash
            self.class.hash ^ id.hash
          end
        end
      end
    end
  end
end
