module Contror
  class DotHelper
    using Contror::ObjectTry

    attr_reader :graph

    def initialize(graph:)
      @graph = graph
    end

    def vertex_id(vertex)
      case vertex
      when Symbol
        "\"#{graph.__id__}@#{vertex.to_s}\""
      when Graph::Vertex
        "\"#{graph.__id__}@#{vertex.stmt.dest}@#{vertex.label || "-"}\""
      end
    end

    def vertex_decl(vertex)
      label = case vertex
              when Symbol
                if graph.stmt.is_a?(ANF::AST::Stmt::Def)
                  "#{graph.stmt.name}:#{vertex}"
                else
                  "[toplevel]:#{vertex}"
                end
              when Graph::Vertex
                vertex_caption(vertex)
              else
                raise "Unexpected vertex: #{vertex.class}"
              end

      shape = case vertex
              when Symbol
                "circle"
              when Graph::Vertex
                "box"
              end

      "#{vertex_id(vertex)}[label=\"#{label}\", shape=#{shape}];"
    end

    def vertex_caption(v)
      s = v.stmt.class.name.split(/::/).last.downcase
      loc = v.stmt.node&.loc&.try {|l|
        "#{l.first_line}:#{l.column}"
      }
      label = v.label

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

      "#{v.stmt.dest}#{s}#{label && "(#{label})"}:#{loc}#{suffix && ":" + suffix}"
    end

    def edge_option(edge)
      if edge.label
        "[label=\"#{edge.label}\"]"
      else
        ""
      end
    end
  end
end
