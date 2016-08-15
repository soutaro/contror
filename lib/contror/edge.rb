module Contror
  module Vertex
    class Base
      attr_reader :node
    end

    class Variable

    end

    class Start < Base
      attr_reader :node
    end

    class End < Base
      attr_reader :node
    end

    class Send < Base
      attr_reader :node

      attr_reader :receiver
      attr_reader :args
      attr_reader :block
    end

    class Assign < Base
      attr_reader :variable
      attr_reader :expr
    end

    class Var < Base
      attr_reader :node
    end
  end
end
