require 'thor'
require "pathname"
require "rainbow"
require "pp"

module Contror
  class CLI < Thor
    desc "parse PATH...", "Parse ruby files given as path"
    def parse(*args)
      each_ruby_script args do |path|
        print Rainbow("Parsing").green + " #{path} ... "
        STDOUT.flush

        begin
          node = Parser::CurrentRuby.parse(path.read, path.to_s)
          anf = ANF::Translator.new.translate(node: node) if node

          puts Rainbow("OK").blue

        rescue => exn
          puts Rainbow("Failed").red
          p exn
        end
      end
    end

    desc "anf PATH...", "Translate given script to ANF, and print it"
    def anf(*args)
      each_ruby_script args do |path|
        puts Rainbow("Translate #{path} to ANF:").green

        node = Parser::CurrentRuby.parse(path.read, path.to_s)
        anf = ANF::Translator.new.translate(node: node)

        pp anf
      end
    end

    desc "dot PATH", "print dot"
    def dot(path)
      path = Pathname(path)

      node = Parser::CurrentRuby.parse(path.read, path.to_s)
      anf = ANF::Translator.new.translate(node: node)

      builder = Graph::Builder.new(stmt: anf)

      puts "digraph a {"

      builder.each_graph do |graph|
        graph.each_edge do |edge|
          src = format_vertex(edge.source, graph: graph)
          dest = format_vertex(edge.destination, graph: graph)
          puts "\"#{src}\" -> \"#{dest}\" #{edge_option(edge)};"
        end
      end

      puts "}"
    end

    private

    def format_vertex(v, graph:)
      case v
      when Symbol
        if graph.stmt.is_a?(ANF::AST::Stmt::Def)
          "#{graph.stmt.dest.id}@#{graph.stmt.name}:#{v}"
        else
          "toplevel:#{v}"
        end
      when Graph::Vertex
        stmt = v.stmt
        "#{stmt.dest.id}@#{stmt.class.name}:#{stmt.node.loc.first_line}:#{stmt.node.loc.column}:#{v.label || "-"}"
      end
    end

    def edge_option(edge)
      if edge.label
        "[label=\"#{edge.label}\"]"
      else
        ""
      end
    end

    def each_ruby_script(args, &block)
      args.each do |arg|
        path = Pathname(arg)
        each_ruby_script0(path, &block)
      end
    end

    def each_ruby_script0(path, &block)
      if path.basename.to_s =~ /\A\.[^\.]+/
        return
      end

      case
      when path.directory?
        path.children.each do |child|
          each_ruby_script0 child, &block
        end
      when path.file?
        if path.extname == ".rb"
          yield path
        end
      end
    end
  end
end
