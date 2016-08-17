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

    attr_reader :type
    attr_reader :edges
    attr_reader :vertexes

    def initialize(stmt:, type:)
      @type = type

      @edges = Set.new
      @vertexes = Set.new

      @stmt = stmt

      @start = :start
      @end = :end

      case type
      when :toplevel
        add_edge source: start, destination: @stmt
        build(@stmt, to: self.end)
      when :def
        if @stmt.body
          add_edge source: start, destination: @stmt.body
          build(@stmt.body, to: self.end)
        end
      end
    end

    def start
      @start
    end

    def end
      @end
    end

    def each_edge(&block)
      edges.each &block
    end

    private

    def build(stmt, to:)
      case stmt
      when ANF::AST::Stmt::Block
        stmts = stmt.stmts

        add_edge source: stmt, destination: stmts.first

        stmts.each_cons(2) do |x, y|
          build(x, to: y)
        end

        build(stmts.last, to: to)

      when ANF::AST::Stmt::Module
        add_edge source: stmt, destination: stmt.body
        build(stmt.body, to: to)

      when ANF::AST::Stmt::Class
        add_edge source: stmt, destination: stmt.body
        build(stmt.body, to: to)

      when ANF::AST::Stmt::If
        if stmt.then_clause
          add_edge source: stmt, destination: stmt.then_clause, label: :then
          build stmt.then_clause, to: to
        else
          add_edge source: stmt, destination: to, label: :then
        end

        if stmt.else_clause
          add_edge source: stmt, destination: stmt.else_clause, label: :else
          build stmt.else_clause, to: to
        else
          add_edge source: stmt, destination: to, label: :else
        end

      when ANF::AST::Stmt::Case
        vertex = stmt

        stmt.whens.each do |w|
          if w.pattern
            pat_end = Vertex.new(stmt: w.pattern, label: :case_test_end)

            add_edge source: vertex, destination: w.pattern
            build w.pattern, to: pat_end
            add_edge source: pat_end, destination: w.body
            build w.body, to: to

            vertex = pat_end
          else
            add_edge source: vertex, destination: w.body
            build w.body, to: to
          end
        end

      when ANF::AST::Stmt::Call
        if stmt&.block&.body
          add_edge source: stmt, destination: stmt.block.body, label: :block_yield

          block_exit = Vertex.new(stmt: stmt, label: :call_exit)
          build stmt.block.body, to: block_exit

          add_edge source: block_exit, destination: to

        else
          add_edge source: stmt, destination: to
        end

      when ANF::AST::Stmt::Rescue
        if stmt.body
          add_edge source: stmt, destination: stmt.body, label: :begin
          build stmt.body, to: to

          source_vertex = Vertex.new(stmt: stmt.body)
          for res in stmt.rescues
            if res.class_stmt
              add_edge source: source_vertex, destination: res.class_stmt
              if res.body
                build res.class_stmt, to: res.body
                build res.body, to: to
              else
                build res.class_stmt, to: to
              end

              source_vertex = Vertex.new(stmt: res.class_stmt)
            else
              if res.body
                add_edge source: source_vertex, destination: res.body
                build res.body, to: to
              else
                add_edge source: source_vertex, destination: to
              end
            end
          end
        else
          add_edge source: stmt, destination: to
        end

      when ANF::AST::Stmt::Ensure
        if stmt.ensured
          add_edge source: stmt, destination: stmt.ensured
          if stmt.ensuring
            build stmt.ensured, to: stmt.ensuring
            build stmt.ensuring, to: to
          else
            build stmt.ensured, to: to
          end
        else
          add_edge source: stmt, destination: stmt.ensuring, label: :ensure
          build stmt.ensuring, to: to
        end

      else
        add_edge source: stmt, destination: to
      end
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
