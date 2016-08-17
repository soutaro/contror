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

      def has
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

      def has
        self.class.hash ^ label.hash ^ stmt.hash
      end
    end

    attr_reader :edges
    attr_reader :vertexes

    def initialize(stmt:)
      @edges = Set.new
      @vertexes = Set.new

      @stmt = stmt

      @start = :start
      @end = :end

      build(@stmt, from: start, to: self.end)
    end

    def start
      @start
    end

    def end
      @end
    end

    private

    def build(stmt, from:, to:)
      case stmt
      when ANF::AST::Stmt::Block
        enter_node = Vertex.new(stmt: stmt, label: :enter)
        add_edge source: from, destination: enter_node

        

        exit_node = Vertex.new(stmt: stmt, label: :exit)
        add_edge source: exit_node, destination: to
      end
    end

    def add_edge(source:, destination:, label: nil)
      Edge.new(source: source, destination: destination, label: label).tap do |edge|
        @vertexes << edge.source
        @vertexes << edge.destination
        @edges << edge
      end
    end
  end
end
