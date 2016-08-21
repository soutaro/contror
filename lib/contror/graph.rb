module Contror
  class Graph
    class Edge
      attr_reader :source
      attr_reader :destination
      attr_reader :label

      def initialize(source:, destination:, label: nil)
        @source = source
        @destination = destination
        @label = label
      end

      def eql?(other)
        self == other
      end

      def ==(other)
        other.is_a?(self.class) && source == other.source && destination == other.destination && label == other.label
      end

      def hash
        self.class.hash ^ label.hash ^ source.hash ^ destination.hash
      end
    end

    class Vertex
      attr_reader :stmt
      attr_reader :label

      def initialize(stmt:, label: nil)
        @stmt = stmt
        @label = label
      end

      def eql?(other)
        self == other
      end

      def ==(other)
        other.is_a?(self.class) && stmt == other.stmt && label == other.label
      end

      def hash
        self.class.hash ^ label.hash ^ stmt.hash
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

      @start = :start
      @end = :end
    end

    def each_edge(&block)
      edges.each &block
    end

    def each_vertex(&block)
      vertexes.each &block
    end

    def add_edge(source:, destination:, label: nil)
      if source.is_a?(ANF::AST::Stmt::Base)
        source = Vertex.new(stmt: source)
      end

      if destination.is_a?(ANF::AST::Stmt::Base)
        destination = Vertex.new(stmt: destination)
      end

      Edge.new(source: source, destination: destination, label: label).tap do |edge|
        @vertexes << edge.source
        @vertexes << edge.destination
        @edges << edge
      end
    end
  end
end
