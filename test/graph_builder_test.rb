require_relative 'test_helper'

class GraphBuilderTest < Minitest::Test
  def translate(source)
    node = parse(source)
    translator = Contror::ANF::Translator.new
    stmt = translator.translate(node: node)

    yield stmt, node
  end

  def test_building_graph_of_toplevel
    translate "p x: 3" do |ast, node|
      graphs = Contror::Graph::Builder.new(stmt: ast).each_graph.to_a

      assert_equal 1, graphs.size
      assert_equal node, graphs.first.stmt.node
    end
  end

  def test_building_graph_of_methods
    translate <<-EOS do |ast|
      def f(x, y, z)
        if x
          y
        else
          z
        end
      end

      f(true, :x, :y)
    EOS
      graphs = Contror::Graph::Builder.new(stmt: ast).each_graph.to_a

      assert_equal 2, graphs.size

      assert_instance_of Contror::ANF::AST::Stmt::Block, graphs[0].stmt

      assert_instance_of Contror::ANF::AST::Stmt::Def, graphs[1].stmt
      assert_equal :f, graphs[1].stmt.name
    end
  end
end
