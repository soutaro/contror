module Contror
  class DotHelper
    using Contror::ObjectTry

    attr_reader :graph

    def initialize(graph:)
      @graph = graph
    end

    def vertex_id(vertex)
      case vertex
      when Graph::Vertex::Label
        vertex.__id__.to_s
      when Graph::Vertex::Special
        vertex.__id__.to_s
      when Graph::Vertex::Stmt
        "\"#{graph.__id__}@#{vertex.stmt.dest}\""
      end
    end

    def vertex_decl(vertex)
      label = case vertex
              when Graph::Vertex::Special
                if graph.stmt.is_a?(ANF::AST::Stmt::Def)
                  "#{graph.stmt.name}:#{vertex.type}"
                else
                  "[toplevel]:#{vertex.type}"
                end
              when Graph::Vertex::Label
                ":#{vertex.label}"
              when Graph::Vertex::Stmt
                vertex_caption(vertex)
              else
                raise "Unexpected vertex: #{vertex.class}"
              end

      shape = case vertex
              when Graph::Vertex::Special
                "circle"
              when Graph::Vertex::Stmt, Graph::Vertex::Label
                "box"
              end

      fontcolor = case vertex
                  when Graph::Vertex::Label
                    "#808080"
                  else
                    "#000000"
                  end

      "#{vertex_id(vertex)}[label=\"#{label}\", shape=#{shape}, fontcolor=\"#{fontcolor}\"];"
    end

    def vertex_caption(v)
      s = v.stmt.class.name.split(/::/).last.downcase
      loc = v.stmt.node&.loc&.try {|l|
        "#{l.first_line}:#{l.column}"
      }

      suffix = case v.stmt
               when ANF::AST::Stmt::Call
                 v.stmt.name.to_s
               when ANF::AST::Stmt::Assign
                 "-> #{v.stmt.lhs.to_s}"
               when ANF::AST::Stmt::Constant
                 "#{v.stmt.name}"
               when ANF::AST::Stmt::ConstantAssign
                 "-> #{v.stmt.name}"
               when ANF::AST::Stmt::Jump
                 v.stmt.type.to_s
               else
                 nil
               end

      "#{v.stmt.dest}#{s}:#{loc}#{suffix && ":" + suffix}"
    end
  end
end
