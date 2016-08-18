module Contror
  class Graph
    class Builder
      attr_reader :stmt
      attr_reader :graphs

      def initialize(stmt:)
        @stmt = stmt
      end

      def each_graph(&block)
        if block_given?
          unless graphs
            construct
          end

          graphs.each(&block)
        else
          enum_for :each_graph
        end
      end

      private

      def construct
        @graphs = []

        build_block(stmt)

        stmt.each_sub_stmt(recursively: true) do |stmt|
          if stmt.is_a?(ANF::AST::Stmt::Def)
            build_def(stmt)
          end
        end
      end

      def build_block(stmt)
        graph = Graph.new(stmt: stmt)

        graph.add_edge(source: :start, destination: stmt)
        build(graph, stmt, to: :end)

        graphs << graph
      end

      def build_def(stmt)
        graph = Graph.new(stmt: stmt)

        if stmt.body
          graph.add_edge source: :start, destination: stmt.body
          build graph, stmt.body, to: :end
        else
          graph.add_edge(source: :start, destination: :end)
        end

        graphs << graph
      end

      def build(graph, stmt, to:)
        case stmt
        when ANF::AST::Stmt::Block
          stmts = stmt.stmts

          graph.add_edge source: stmt, destination: stmts.first

          stmts.each_cons(2) do |x, y|
            build(graph, x, to: y)
          end

          build(graph, stmts.last, to: to)

        when ANF::AST::Stmt::Module
          graph.add_edge source: stmt, destination: stmt.body
          build(graph, stmt.body, to: to)

        when ANF::AST::Stmt::Class
          graph.add_edge source: stmt, destination: stmt.body
          build(graph, stmt.body, to: to)

        when ANF::AST::Stmt::If
          if stmt.then_clause
            graph.add_edge source: stmt, destination: stmt.then_clause, label: :then
            build graph, stmt.then_clause, to: to
          else
            graph.add_edge source: stmt, destination: to, label: :then
          end

          if stmt.else_clause
            graph.add_edge source: stmt, destination: stmt.else_clause, label: :else
            build graph, stmt.else_clause, to: to
          else
            graph.add_edge source: stmt, destination: to, label: :else
          end

        when ANF::AST::Stmt::Case
          vertex = stmt

          stmt.whens.each do |w|
            if w.pattern
              pat_end = Vertex.new(stmt: w.pattern, label: :case_test_end)

              graph.add_edge source: vertex, destination: w.pattern
              build graph, w.pattern, to: pat_end
              graph.add_edge source: pat_end, destination: w.body
              build graph, w.body, to: to

              vertex = pat_end
            else
              graph.add_edge source: vertex, destination: w.body
              build graph, w.body, to: to
            end
          end

        when ANF::AST::Stmt::Call
          if stmt&.block&.body
            graph.add_edge source: stmt, destination: stmt.block.body, label: :block_yield

            block_exit = Vertex.new(stmt: stmt, label: :call_exit)
            build graph, stmt.block.body, to: block_exit

            graph.add_edge source: block_exit, destination: to

          else
            graph.add_edge source: stmt, destination: to
          end

        when ANF::AST::Stmt::Rescue
          if stmt.body
            graph.add_edge source: stmt, destination: stmt.body, label: :begin
            build graph, stmt.body, to: to

            source_vertex = Vertex.new(stmt: stmt.body)
            for res in stmt.rescues
              if res.class_stmt
                graph.add_edge source: source_vertex, destination: res.class_stmt
                if res.body
                  build graph, res.class_stmt, to: res.body
                  build graph, res.body, to: to
                else
                  build graph, res.class_stmt, to: to
                end

                source_vertex = Vertex.new(stmt: res.class_stmt)
              else
                if res.body
                  graph.add_edge source: source_vertex, destination: res.body
                  build graph, res.body, to: to
                else
                  graph.add_edge source: source_vertex, destination: to
                end
              end
            end
          else
            graph.add_edge source: stmt, destination: to
          end

        when ANF::AST::Stmt::Ensure
          if stmt.ensured
            graph.add_edge source: stmt, destination: stmt.ensured
            if stmt.ensuring
              build graph, stmt.ensured, to: stmt.ensuring
              build graph, stmt.ensuring, to: to
            else
              build graph, stmt.ensured, to: to
            end
          else
            graph.add_edge source: stmt, destination: stmt.ensuring, label: :ensure
            build graph, stmt.ensuring, to: to
          end

        else
          graph.add_edge source: stmt, destination: to
        end
      end
    end
  end
end
