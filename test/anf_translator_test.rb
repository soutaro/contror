require_relative 'test_helper'

class ANFTranslatorTest < Minitest::Test
  def translate(source)
    node = parse(source)
    translator = Contror::ANF::Translator.new
    stmt = translator.translate(node: node)

    yield stmt, node
  end

  AST = Contror::ANF::AST

  # x is instance of y
  # x is equal to y
  def assert_instance_or_value(expected, actual)
    if expected.is_a?(Class)
      assert_instance_of expected, actual
    else
      assert_equal expected, actual
    end
  end

  def assert_value_stmt(expected, actual)
    assert_instance_of AST::Stmt::Value, actual
    assert_value expected, actual.value
  end

  def assert_value(expected, actual)
    if expected == nil
      assert_nil actual
      return
    end

    if expected.is_a?(AST::Variable::Base)
      assert_instance_or_value expected, actual
    else
      assert_instance_of Parser::AST::Node, actual

      case expected
      when Hash
        assert_equal expected[:type], actual.type if expected[:type]
        assert_equal expected[:value], actual.children.first if expected[:value]
      when Symbol
        if actual.type == expected
          assert_equal expected, actual.type
        else
          assert_equal :sym, actual.type
          assert_equal expected, actual.children.first
        end
      else
        assert_equal expected, actual.children.first
      end
    end
  end

  def assert_assign_stmt(stmt, lhs: nil, rhs: nil)
    assert_instance_of AST::Stmt::Assign, stmt

    assert_instance_or_value lhs, stmt.lhs if lhs
    assert_value rhs, stmt.rhs if rhs

    yield stmt.lhs, stmt.rhs if block_given?
  end

  def assert_call_stmt(stmt, receiver:, name:, args:)
    assert_instance_of AST::Stmt::Call, stmt

    if receiver
      assert_value receiver, stmt.receiver
    else
      assert_nil stmt.receiver
    end
    assert_equal stmt.name, name

    if args
      assert_equal args.size, stmt.args.size
      args.each.with_index do |arg, index|
        assert_value arg, stmt.args[index]
      end
    end

    yield stmt.block if block_given?
  end

  def test_translate_lasign
    translate("x = 3") do |ast|
      assert_assign_stmt ast, lhs: AST::Variable::Local.new(name: :x), rhs: 3
    end
  end

  def test_translate_lasign_lasign
    translate("x = y = 3") do |ast|
      assert_block_stmt ast do |stmts|
        assert_assign_stmt stmts[0], lhs: AST::Variable::Local.new(name: :y), rhs: 3
        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
    end
  end

  def test_translate_call
    translate("1+2") do |ast|
      assert_call_stmt ast, receiver: 1, name: :+, args: [2]
    end

    translate("f().g(h())") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
        assert_call_stmt stmts[1], receiver: nil, name: :h, args: []
        assert_call_stmt stmts[2], receiver: stmts[0].dest, name: :g, args: [stmts[1].dest]
      end
    end

    translate("5.each(&block)") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :block, args: []
        assert_call_stmt stmts[1], receiver: 5, name: :each, args: [AST::Variable::BlockPass.new(var: stmts[0].dest)]
      end
    end

    translate("f(*[])") do |ast|
      assert_block_stmt ast do |stmts|
        assert_array_stmt stmts[0], elements: []
        assert_call_stmt stmts[1], receiver: nil, name: :f, args: [AST::Variable::Splat.new(var: stmts[0].dest)]
      end
    end

    translate("f(x: 1+2)") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: 1, name: :+, args: [2]
        assert_hash_stmt stmts[1], pairs: [[:x, stmts[0].dest]]
        assert_call_stmt stmts[2], receiver: nil, name: :f, args: [stmts[1].dest]
      end
    end
  end

  def test_translate_call_with_block
    translate("3.each do |x| end") do |ast|
      assert_call_stmt ast, receiver: 3, name: :each, args: [] do |block|
        assert_def_param block.params[0], type: :arg, name: :x, default: nil
        assert_nil block.body
      end
    end
  end

  def test_translate_csend
    translate("1&.f") do |ast|
      assert_if_stmt ast, condition: 1 do |t, f|
        assert_call_stmt t, receiver: 1, name: :f, args: []
        assert_nil f
      end
    end
  end

  def assert_if_stmt(stmt, condition:)
    assert_instance_of AST::Stmt::If, stmt
    assert_value condition, stmt.condition
    yield stmt.then_clause, stmt.else_clause if block_given?
  end

  def test_translate_if
    translate("if x() then y() else z() end") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :x, args: []
        assert_if_stmt stmts[1], condition: stmts[0].dest do |t, f|
          assert_call_stmt t, receiver: nil, name: :y, args: []
          assert_call_stmt f, receiver: nil, name: :z, args: []
        end
      end
    end

    translate("if x() then y() end") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :x, args: []
        assert_if_stmt stmts[1], condition: stmts[0].dest do |t, f|
          assert_call_stmt t, receiver: nil, name: :y, args: []
          assert_nil f
        end
      end
    end

    translate("unless x() then y() end") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :x, args: []
        assert_if_stmt stmts[1], condition: stmts[0].dest do |t, f|
          assert_nil t
          assert_call_stmt f, receiver: nil, name: :y, args: []
        end
      end
    end

    translate("x = 1 ? 2 : 3") do |ast|
      assert_block_stmt ast do |stmts|
        assert_if_stmt stmts[0], condition: 1 do |t, f|
          assert_value_stmt 2, t
          assert_value_stmt 3, f
        end
        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
    end
  end

  def assert_loop_stmt(ast)
    assert_instance_of AST::Stmt::Loop, ast
    yield ast.body if block_given?
  end

  def assert_jump_stmt(stmt, type:, args:)
    assert_instance_of AST::Stmt::Jump, stmt
    assert_equal type, stmt.type

    if args
      assert_equal args.size, stmt.args.size
      args.each.with_index do |a, index|
        assert_value args[index], a
      end
    else
      assert_equal args, stmt.args
    end
  end

  def test_translate_loop
    translate <<-EOS do |ast|
      while f()
        g()
      end
    EOS
      assert_loop_stmt ast do |body|
        assert_block_stmt body do |stmts|
          assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
          assert_if_stmt stmts[1], condition: stmts[0].dest do |t, f|
            assert_nil t
            assert_jump_stmt f, type: :break, args: []
          end
        end
      end
    end

    translate <<-EOS do |ast|
      until f()
        g()
      end
    EOS
      assert_loop_stmt ast do |body|
        assert_block_stmt body do |stmts|
          assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
          assert_if_stmt stmts[1], condition: stmts[0].dest do |t, f|
            assert_jump_stmt t, type: :break, args: []
            assert_nil f
          end
        end
      end
    end

    translate <<-EOS do |ast|
      x = while f()
      end
    EOS
      assert_block_stmt ast do |stmts|
        assert_loop_stmt stmts[0] do |body|
          assert_block_stmt body
        end

        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
    end
  end

  def assert_array_stmt(stmt, elements:)
    assert_instance_of AST::Stmt::Array, stmt

    if elements
      assert_equal elements.size, stmt.elements.size
      stmt.elements.each.with_index do |a, i|
        assert_value elements[i], a
      end
    end

    yield stmt.elements if block_given?
  end

  def test_translate_literals
    translate("f(1, 1.0, 'a', :b, true, false, self, nil, 1i, 1r)") do |ast|
      assert_call_stmt ast, receiver: nil, name: :f, args: [1, 1.0, 'a', :b, :true, :false, :self, :nil, 1i, 1r]
    end
  end

  def test_translate_array
    translate("[]") do |ast|
      assert_array_stmt ast, elements: []
    end

    translate("[1, true, false, nil]") do |ast|
      assert_array_stmt ast, elements: [1, :true, :false, :nil]
    end

    translate("[@a]") do |ast|
      assert_array_stmt ast, elements: [AST::Variable::Instance.new(name: :"@a")]
    end

    # array elements should be value
    translate("[f()]") do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
        assert_array_stmt stmts[1], elements: [stmts[0].dest]
      end
    end
  end

  def assert_hash_stmt(stmt, pairs: nil, splat: nil)
    assert_instance_of AST::Stmt::Hash, stmt

    if pairs
      assert_equal pairs.count, stmt.pairs.count

      pairs.each.with_index do |expected, index|
        actual = stmt.pairs[index]

        assert_value expected[0], actual.key
        assert_value expected[1], actual.value
      end
    end

    assert_value splat, stmt.splat
  end

  def test_translate_hash
    translate "{}" do |ast|
      assert_hash_stmt ast
    end

    translate "{ a: 1, b: :x }" do |ast|
      assert_hash_stmt(ast, pairs: [[:a, 1], [:b, :x]])
    end

    translate "{ a: 1, **f }" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
        assert_hash_stmt stmts[1], pairs: [[:a, 1]], splat: stmts[0].dest
      end
    end
  end

  def test_local_variable
    source = <<-EOS
      a = 1
      _ = a
    EOS

    translate(source) do |ast|
      assert_block_stmt ast do |stmts|
        assert_assign_stmt stmts[0], lhs: AST::Variable::Local.new(name: :a), rhs: 1
        assert_assign_stmt stmts[1], rhs: AST::Variable::Local.new(name: :a)
      end
    end
  end

  def test_instance_variable
    source = <<-EOS
      @a = 1
      _ = @a
    EOS

    translate(source) do |ast|
      assert_block_stmt ast do |stmts|
        assert_assign_stmt stmts[0], lhs: AST::Variable::Instance.new(name: :"@a"), rhs: 1
        assert_assign_stmt stmts[1], rhs: AST::Variable::Instance.new(name: :"@a")
      end
    end
  end

  def test_global_variable
    source = <<-EOS
      $a = 2
      _ = $a
    EOS

    translate(source) do |ast|
      assert_block_stmt ast do |stmts|
        assert_assign_stmt stmts[0], lhs: AST::Variable::Global.new(name: :"$a"), rhs: 2
        assert_assign_stmt stmts[1], rhs: AST::Variable::Global.new(name: :"$a")
      end
    end
  end

  def test_class_variable
    source = <<-EOS
      @@a = 2
      _ = @@a
    EOS

    translate(source) do |ast|
      assert_block_stmt ast do |stmts|
        assert_assign_stmt stmts[0], lhs: AST::Variable::Class.new(name: :"@@a"), rhs: 2
        assert_assign_stmt stmts[1], rhs: AST::Variable::Class.new(name: :"@@a")
      end
    end
  end

  def assert_const_assign_stmt(stmt, prefix:, name:, rhs: nil)
    assert_instance_of AST::Stmt::ConstantAssign, stmt

    assert_value prefix, stmt.prefix
    assert_equal name, stmt.name
    assert_value rhs, stmt.value
  end

  def assert_const_stmt(stmt, prefix:, name:)
    assert_instance_of AST::Stmt::Constant, stmt

    assert_value prefix, stmt.prefix
    assert_equal name, stmt.name
  end

  def test_constant
    translate(<<-EOS) do |ast|
      C = 3
      _ = C
    EOS
      assert_block_stmt ast do |stmts|
        assert_const_assign_stmt stmts[0], prefix: nil, name: :C, rhs: 3
        assert_const_stmt stmts[1], prefix: nil, name: :C
      end
    end

    translate(<<-EOS) do |ast|
      A::B = 3
      _ = A::B
    EOS
      assert_block_stmt ast do |stmts|
        assert_const_stmt stmts[0], prefix: nil, name: :A
        assert_const_assign_stmt stmts[1], prefix: stmts[0].dest, name: :B, rhs: 3

        assert_const_stmt stmts[2], prefix: nil, name: :A
        assert_const_stmt stmts[3], prefix: stmts[2].dest, name: :B
        assert_assign_stmt stmts[4], rhs: stmts[3].dest
      end
    end

    translate(<<-EOS) do |ast|
      ::X = 1
      _ = ::X
    EOS
      assert_block_stmt ast do |stmts|
        assert_const_assign_stmt stmts[0], prefix: :cbase, name: :X, rhs: 1
        assert_const_stmt stmts[1], prefix: :cbase, name: :X
      end
    end
  end

  def assert_def_stmt(stmt, object:, name:)
    assert_instance_of AST::Stmt::Def, stmt
    assert_value object, stmt.object
    assert_equal name, stmt.name
    yield stmt.params, stmt.body if block_given?
  end

  def test_translate_def
    translate("def f(); 3; end") do |ast|
      assert_def_stmt ast, object: nil, name: :f do |params, body|
        assert_empty params
        assert_value_stmt 3, body
      end
    end

    translate("def f(); end") do |ast|
      assert_def_stmt ast, object: nil, name: :f do |params, body|
        assert_empty params
        assert_nil body
      end
    end

    translate("def f(a, b=1, *c, d:, e: (x = 1; x+1), **f, &g); end") do |ast|
      assert_def_stmt ast, object: nil, name: :f do |params|
        assert_def_param params[0], type: :arg, name: :a, default: nil
        assert_def_param params[1], type: :optarg, name: :b do |stmt|
          assert_value_stmt 1, stmt
        end
        assert_def_param params[2], type: :restarg, name: :c, default: nil
        assert_def_param params[3], type: :kwarg, name: :d, default: nil
        assert_def_param params[4], type: :kwoptarg, name: :e do |stmt|
          assert_block_stmt stmt do |stmts|
            assert_assign_stmt stmts[0], lhs: AST::Variable::Local.new(name: :x), rhs: 1
            assert_call_stmt stmts[1], receiver: AST::Variable::Local.new(name: :x), name: :+, args: [1]
          end
        end
        assert_def_param params[5], type: :kwrestarg, name: :f, default: nil
        assert_def_param params[6], type: :blockarg, name: :g, default: nil
      end
    end

    translate("private def hoge; end") do |ast|
      assert_block_stmt ast do |stmts|
        assert_def_stmt stmts[0], object: nil, name: :hoge
        assert_call_stmt stmts[1], receiver: nil, name: :private, args: [stmts[0].dest]
      end
    end

    translate "def (f()).g(); end" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
        assert_def_stmt stmts[1], object: stmts[0].dest, name: :g
      end
    end
  end

  def assert_class_stmt(stmt, name:, super_class:)
    assert_instance_of AST::Stmt::Class, stmt

    assert_value name, stmt.name
    assert_value super_class, stmt.super_class

    yield stmt.body if block_given?
  end

  def test_translate_class
    translate <<-EOS do |ast|
      class A; end
    EOS
      assert_block_stmt ast do |stmts|
        assert_const_stmt stmts[0], prefix: nil, name: :A
        assert_class_stmt stmts[1], name: stmts[0].dest, super_class: nil do |body|
          assert_nil body
        end
      end
    end

    translate <<-EOS do |ast|
      class A::B < Object; end
    EOS
      assert_block_stmt ast do |stmts|
        assert_const_stmt stmts[0], prefix: nil, name: :A
        assert_const_stmt stmts[1], prefix: stmts[0].dest, name: :B
        assert_const_stmt stmts[2], prefix: nil, name: :Object
        assert_class_stmt stmts[3], name: stmts[1].dest, super_class: stmts[2].dest do |body|
          assert_nil body
        end
      end
    end
  end

  def test_translate_module
    translate "module X; end" do |ast|
      assert_block_stmt ast do |stmts|
        assert_const_stmt stmts[0], prefix: nil, name: :X

        assert_instance_of AST::Stmt::Module, stmts[1]
        assert_value stmts[0].dest, stmts[1].name

        assert_nil stmts[1].body
      end
    end
  end

  def test_singleton_class
    translate "class <<self; end" do |ast|
      assert_instance_of AST::Stmt::SingletonClass, ast
      assert_value :self, ast.object
      assert_nil ast.body
    end
  end

  def test_translate_jump
    translate "retry" do |ast|
      assert_jump_stmt ast, type: :retry, args: nil
    end

    translate "next" do |ast|
      assert_jump_stmt ast, type: :next, args: nil
    end

    translate "break" do |ast|
      assert_jump_stmt ast, type: :break, args: []
    end

    translate "break f()" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []
        assert_jump_stmt stmts[1], type: :break, args: [stmts[0].dest]
      end
    end
  end

  def test_translate_yield
    translate "yield 1, *f" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []

        assert_instance_of AST::Stmt::Yield, stmts[1]
        assert_value 1, stmts[1].args[0]
        assert_value AST::Variable::Splat.new(var: stmts[0].dest), stmts[1].args[1]
      end
    end
  end

  def test_translate_lambda
    translate "->(x) { x }" do |ast|
      assert_instance_of AST::Stmt::Lambda, ast

      assert_def_param ast.params[0], type: :arg, name: :x
      assert_value_stmt AST::Variable::Local.new(name: :x), ast.body
    end
  end

  def test_translate_dstr
    translate '"hello #{f()}"' do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :f, args: []

        assert_instance_of AST::Stmt::Dstr, stmts[1]
        assert_value "hello ", stmts[1].components[0]
        assert_value stmts[0].dest, stmts[1].components[1]
      end
    end
  end

  def test_translate_and
    translate "1 && self" do |ast|
      assert_if_stmt ast, condition: 1 do |t, f|
        assert_value_stmt :self, t
        assert_nil f
      end
    end
  end

  def test_translate_or
    translate "1 || 2" do |ast|
      assert_if_stmt ast, condition: 1 do |t, f|
        assert_nil t
        assert_value_stmt 2, f
      end
    end
  end

  def test_translate_masgn
    translate "a, *b = x" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :x, args: []

        assert_instance_of AST::Stmt::MAssign, stmts[1]
        assert_value stmts[0].dest, stmts[1].rhs
        assert_equal AST::Variable::Local.new(name: :a), stmts[1].vars[0]
        assert_equal AST::Variable::Splat.new(var: AST::Variable::Local.new(name: :b)), stmts[1].vars[1]
      end
    end
  end

  def test_translate_rescue
    translate <<-EOS do |ast|
      begin
        0
      rescue A => exn
        1
      rescue
        2
      end
    EOS
      assert_instance_of AST::Stmt::Rescue, ast

      assert_value_stmt 0, ast.body

      assert_equal 2, ast.rescues.size

      r1 = ast.rescues[0]
      assert_block_stmt r1.class_stmt do |stmts|
        assert_const_stmt stmts[0], prefix: nil, name: :A
        assert_array_stmt stmts[1], elements: [stmts[0].dest]
      end
      assert_equal AST::Variable::Local.new(name: :exn), r1.var
      assert_value_stmt 1, r1.body

      r2 = ast.rescues[1]
      assert_nil r2.class_stmt
      assert_nil r2.var
      assert_value_stmt 2, r2.body
    end
  end

  def test_translate_ensure
    translate <<-EOS do |ast|
      begin
        0
      ensure
        1
      end
    EOS
      assert_instance_of AST::Stmt::Ensure, ast
      assert_value_stmt 0, ast.ensured
      assert_value_stmt 1, ast.ensuring
    end
  end

  def test_translate_case
    translate <<-EOS do |ast|
      case 1
      when 2
        3
      else
        4
      end
    EOS
      assert_instance_of AST::Stmt::Case, ast

      assert_value 1, ast.condition

      assert_equal 2, ast.whens.count

      assert_value_stmt 2, ast.whens[0].pattern
      assert_value_stmt 3, ast.whens[0].body

      assert_nil ast.whens[1].pattern
      assert_value_stmt 4, ast.whens[1].body
    end

    translate <<-EOS do |ast|
      case
      when 2
        3
      else
        4
      end
    EOS
      assert_instance_of AST::Stmt::Case, ast

      assert_nil ast.condition

      assert_equal 2, ast.whens.count

      assert_value_stmt 2, ast.whens[0].pattern
      assert_value_stmt 3, ast.whens[0].body

      assert_nil ast.whens[1].pattern
      assert_value_stmt 4, ast.whens[1].body
    end

    translate <<-EOS do |ast|
      case
      when 2
        3
      end
    EOS
      assert_instance_of AST::Stmt::Case, ast

      assert_nil ast.condition

      assert_equal 1, ast.whens.count

      assert_value_stmt 2, ast.whens[0].pattern
      assert_value_stmt 3, ast.whens[0].body
    end
  end

  def test_translate_super
    translate "super" do |ast|
      assert_instance_of AST::Stmt::ZSuper, ast
    end

    translate "super(1)" do |ast|
      assert_instance_of AST::Stmt::Super, ast

      assert_equal 1, ast.args.count
      assert_value 1, ast.args[0]
    end
  end

  def assert_block_stmt(stmt)
    assert_instance_of AST::Stmt::Block, stmt
    yield stmt.stmts if block_given?
  end

  def assert_def_param(param, type:, name:, default: false)
    assert_equal type, param[0]
    assert_equal name, param[1]

    case default
    when nil
      assert_nil param[2]
    end

    yield param[2] if block_given?
  end
end
