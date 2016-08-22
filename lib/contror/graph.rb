module Contror
  class Graph
    class Edge
      attr_reader :source
      attr_reader :destination

      def initialize(source:, destination:)
        @source = source
        @destination = destination
      end

      def eql?(other)
        self == other
      end

      def ==(other)
        other.is_a?(self.class) && source == other.source && destination == other.destination
      end

      def hash
        self.class.hash ^ source.hash ^ destination.hash
      end
    end

    module Vertex
      class Base; end

      class Stmt < Base
        attr_reader :stmt
        attr_reader :label

        def initialize(stmt:)
          @stmt = stmt
        end

        def eql?(other)
          self == other
        end

        def ==(other)
          other.is_a?(self.class) && stmt == other.stmt
        end

        def hash
          self.class.hash ^ stmt.hash
        end
      end

      class Label < Base
        attr_reader :label

        def initialize(label:)
          @label = label
        end
      end

      class Special < Base
        attr_reader :type

        def initialize(type:)
          @type = type
        end
      end
    end

    attr_reader :edges
    attr_reader :vertexes
    attr_reader :start
    attr_reader :end
    attr_reader :stmt

    def initialize(stmt:)
      @stmt = stmt
      @edges = Set.new
      @vertexes = Set.new

      @start = Vertex::Special.new(type: :start)
      @end = Vertex::Special.new(type: :end)
    end

    def each_edge(&block)
      edges.each &block
    end

    def each_vertex(&block)
      vertexes.each &block
    end

    def add_edge(source:, destination:)
      if source.is_a?(ANF::AST::Stmt::Base)
        source = Vertex::Stmt.new(stmt: source)
      end

      if destination.is_a?(ANF::AST::Stmt::Base)
        destination = Vertex::Stmt.new(stmt: destination)
      end

      Edge.new(source: source, destination: destination).tap do |edge|
        @vertexes << edge.source
        @vertexes << edge.destination
        @edges << edge
      end
    end
  end
end
