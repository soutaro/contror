module Contror
  module ANF
    module AST
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

        class BlockPass < Base
          attr_reader :var

          def initialize(var:)
            @var = var
            super()
          end

          def ==(other)
            other.is_a?(self.class) && var == other.var
          end

          def hash
            self.class.hash ^ var.hash
          end
        end

        class Splat < Base
          attr_reader :var

          def initialize(var:)
            @var = var
            super()
          end

          def ==(other)
            other.is_a?(self.class) && var == other.var
          end

          def hash
            self.class.hash ^ var.hash
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
