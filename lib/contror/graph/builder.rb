module Contror
  class Graph
    class Builder
      attr_reader :stmt
      attr_reader :graphs

      attr_reader :break_destinations
      attr_reader :return_destinations
      attr_reader :next_destinations
      attr_reader :retry_destinations
      attr_reader :redo_destinations

      def initialize(stmt:)
        @stmt = stmt
        @break_destinations = []
        @return_destinations = []
        @retry_destinations = []
        @next_destinations = []
        @redo_destinations = []
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

        jump_error = Vertex::Special.new(type: :jump_error)

        graph.add_edge(source: graph.start, destination: stmt)
        push_return_destination jump_error do
          push_break_destination jump_error do
            push_retry_destination jump_error do
              push_next_destination jump_error do
                build(graph, stmt, to: graph.end)
              end
            end
          end
        end

        graphs << graph
      end

      def build_def(stmt)
        graph = Graph.new(stmt: stmt)

        jump_error = Vertex::Special.new(type: :jump_error)

        if stmt.body
          graph.add_edge source: graph.start, destination: stmt.body
          push_return_destination graph.end do
            push_break_destination jump_error do
              push_retry_destination jump_error do
                push_next_destination jump_error do
                  build graph, stmt.body, to: graph.end
                end
              end
            end
          end
        else
          graph.add_edge(source: graph.start, destination: graph.end)
        end

        graphs << graph
      end

      def break_destination
        break_destinations.last
      end

      def push_break_destination(vertex)
        break_destinations.push vertex
        yield
      ensure
        break_destinations.pop
      end

      def return_destination
        return_destinations.last
      end

      def push_return_destination(vertex)
        return_destinations.push vertex
        yield
      ensure
        return_destinations.pop
      end

      def next_destination
        next_destinations.last
      end

      def push_next_destination(vertex)
        next_destinations.push vertex
        yield
      ensure
        next_destinations.pop
      end

      def retry_destination
        retry_destinations.last
      end

      def push_retry_destination(vertex)
        retry_destinations.push vertex
        yield
      ensure
        retry_destinations.pop
      end

      def redo_destination
        redo_destinations.last
      end

      def push_redo_destination(vertex)
        redo_destinations.push vertex
        yield
      ensure
        redo_destinations.pop
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
          if_cond_end = Vertex::Label.new(label: :cond_end)
          if_then = Vertex::Label.new(label: :then)
          if_else = Vertex::Label.new(label: :else)
          if_end = Vertex::Label.new(label: :end)

          graph.add_edge source: stmt, destination: stmt.condition
          build graph, stmt.condition, to: if_cond_end

          graph.add_edge source: if_cond_end, destination: if_then
          if stmt.then_clause
            graph.add_edge source: if_then, destination: stmt.then_clause
            build graph, stmt.then_clause, to: if_end
          else
            graph.add_edge source: if_then, destination: if_end
          end

          graph.add_edge source: if_cond_end, destination: if_else
          if stmt.else_clause
            graph.add_edge source: if_else, destination: stmt.else_clause
            build graph, stmt.else_clause, to: if_end
          else
            graph.add_edge source: if_else, destination: if_end
          end

          graph.add_edge source: if_end, destination: to

        when ANF::AST::Stmt::Case
          cond_end = Vertex::Label.new(label: :cond_end)

          if stmt.condition
            graph.add_edge source: stmt, destination: stmt.condition
            build graph, stmt.condition, to: cond_end
          else
            graph.add_edge source: stmt, destination: cond_end
          end

          vertex = cond_end
          case_end = Vertex::Label.new(label: :end)

          stmt.whens.each do |w|
            if w.pattern
              case_pattern = Vertex::Label.new(label: :case_pattern)
              case_body = Vertex::Label.new(label: :case_body)

              graph.add_edge source: vertex, destination: case_pattern
              graph.add_edge source: case_pattern, destination: w.pattern
              build graph, w.pattern, to: case_body
              graph.add_edge source: case_body, destination: w.body
              build graph, w.body, to: case_end

              vertex = case_body
            else
              # else
              graph.add_edge source: vertex, destination: w.body
              build graph, w.body, to: case_end
            end
          end

          graph.add_edge source: case_end, destination: to

        when ANF::AST::Stmt::Call
          if stmt&.block&.body
            block_start = Vertex::Label.new(label: :block_start)
            block_end = Vertex::Label.new(label: :block_end)
            block_exit = Vertex::Label.new(label: :end)

            graph.add_edge source: stmt, destination: block_start
            graph.add_edge source: block_start, destination: stmt.block.body

            push_break_destination block_exit do
              push_next_destination block_end do
                push_redo_destination block_start do
                  build graph, stmt.block.body, to: block_end
                end
              end
            end

            graph.add_edge source: block_end, destination: block_exit
            graph.add_edge source: block_exit, destination: to
          else
            graph.add_edge source: stmt, destination: to
          end

        when ANF::AST::Stmt::Rescue
          if stmt.body
            begin_start = Vertex::Label.new(label: :begin_start)

            graph.add_edge source: stmt, destination: begin_start, label: :begin
            graph.add_edge source: begin_start, destination: stmt.body
            build graph, stmt.body, to: to

            push_retry_destination begin_start do
              source_vertex = Vertex::Stmt.new(stmt: stmt.body)
              for res in stmt.rescues
                if res.class_stmt
                  graph.add_edge source: source_vertex, destination: res.class_stmt
                  if res.body
                    build graph, res.class_stmt, to: res.body
                    build graph, res.body, to: to
                  else
                    build graph, res.class_stmt, to: to
                  end

                  source_vertex = Vertex::Stmt.new(stmt: res.class_stmt)
                else
                  if res.body
                    graph.add_edge source: source_vertex, destination: res.body
                    build graph, res.body, to: to
                  else
                    graph.add_edge source: source_vertex, destination: to
                  end
                end
              end
            end
          else
            graph.add_edge source: stmt, destination: to
          end

        when ANF::AST::Stmt::Ensure
          ensuring = Vertex::Label.new(label: :ensuring)
          ensure_end = Vertex::Label.new(label: :end)

          if stmt.ensured
            graph.add_edge source: stmt, destination: stmt.ensured
            build graph, stmt.ensured, to: ensuring
          else
            graph.add_edge source: stmt, destination: ensuring
          end

          if stmt.ensuring
            graph.add_edge source: ensuring, destination: stmt.ensuring
            build graph, stmt.ensuring, to: ensure_end
          else
            graph.add_edge source: ensuring, destination: ensure_end
          end

          graph.add_edge source: ensure_end, destination: to

        when ANF::AST::Stmt::For
          loop_start = Vertex::Label.new(label: :for_start)
          loop_end = Vertex::Label.new(label: :for_end)
          loop_exit = Vertex::Label.new(label: :for_exit)

          graph.add_edge source: stmt, destination: stmt.collection
          build graph, stmt.collection, to: loop_start

          if stmt.body
            graph.add_edge source: loop_start, destination: stmt.body
            push_break_destination loop_exit do
              push_next_destination loop_end do
                push_redo_destination loop_start do
                  build graph, stmt.body, to: loop_end
                end
              end
            end
          else
            graph.add_edge source: loop_start, destination: loop_end
          end

          graph.add_edge source: loop_end, destination: loop_exit
          graph.add_edge source: loop_end, destination: loop_start
          graph.add_edge source: loop_exit, destination: to

        when ANF::AST::Stmt::Loop
          loop_start = Vertex::Label.new(label: :loop_start)
          loop_end = Vertex::Label.new(label: :loop_end)
          loop_exit = Vertex::Label.new(label: :loop_exit)

          graph.add_edge source: stmt, destination: loop_start

          if stmt.body
            graph.add_edge source: loop_start, destination: stmt.body
            push_break_destination loop_exit do
              push_next_destination loop_end do
                push_redo_destination loop_start do
                  build graph, stmt.body, to: loop_end
                end
              end
            end
          else
            graph.add_edge source: loop_start, destination: loop_end
          end

          graph.add_edge source: loop_end, destination: loop_exit
          graph.add_edge source: loop_end, destination: loop_start
          graph.add_edge source: loop_exit, destination: to

        when ANF::AST::Stmt::Jump
          case stmt.type
          when :break
            graph.add_edge source: stmt, destination: break_destination
          when :return
            graph.add_edge source: stmt, destination: return_destination
          when :redo
            graph.add_edge source: stmt, destination: redo_destination
          when :retry
            graph.add_edge source: stmt, destination: retry_destination
          else
            raise "Unknown jump type: #{stmt.type}"
          end

        else
          graph.add_edge source: stmt, destination: to
        end
      end
    end
  end
end
