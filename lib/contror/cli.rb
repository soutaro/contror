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

      stmts = [anf]

      anf.each_sub_stmt(recursively: true) do |stmt|
        case stmt
        when ANF::AST::Stmt::Def
          stmts << stmt
        end
      end

      puts "digraph a {"

      stmts.each.with_index do |stmt, index|
        graph = Graph.new(stmt: stmt, type: index == 0 ? :toplevel : :def)
        graph.each_edge do |edge|
          src = format_vertex(edge.source, graph: stmt)
          dest = format_vertex(edge.destination, graph: stmt)
          puts "\"#{src}\" -> \"#{dest}\" #{edge_option(edge)};"
        end
      end

      puts "}"
    end

    private

    def format_vertex(v, graph:)
      case v
      when Symbol
        if graph.is_a?(ANF::AST::Stmt::Def)
          "#{graph.dest.id}@#{graph.name}:#{v}"
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
