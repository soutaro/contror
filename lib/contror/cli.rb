require 'thor'
require "pathname"
require "rainbow"
require "pp"

require 'contror/dot_helper'

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
        helper = DotHelper.new(graph: graph)

        graph.each_vertex do |vertex|
          puts helper.vertex_decl(vertex);
        end

        graph.each_edge do |edge|
          src = helper.vertex_id(edge.source)
          dest = helper.vertex_id(edge.destination)
          puts "#{src} -> #{dest}#{helper.edge_option(edge)};"
        end
      end

      puts "}"
    end

    private

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
