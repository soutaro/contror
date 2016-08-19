require_relative 'test_helper'

class ANFTranslatorTest < Minitest::Test
  def translate(source)
    node = parse(source)
    translator = Contror::ANF::Translator.new
    stmt = translator.translate(node: node)

    yield stmt, node
  end

  include ANFAssertions

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
      assert_if_stmt ast do |c, t, f|
        assert_value_stmt 1, c
        assert_call_stmt t, receiver: 1, name: :f, args: []
        assert_nil f
      end
    end
  end

  def test_translate_if
    translate("if x() then y() else z() end") do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_call_stmt c, receiver: nil, name: :x, args: []
        assert_call_stmt t, receiver: nil, name: :y, args: []
        assert_call_stmt f, receiver: nil, name: :z, args: []
      end
    end

    translate("if x() then y() end") do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_call_stmt c, receiver: nil, name: :x, args: []
        assert_call_stmt t, receiver: nil, name: :y, args: []
        assert_nil f
      end
    end

    translate("unless x() then y() end") do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_call_stmt c, receiver: nil, name: :x, args: []
        assert_nil t
        assert_call_stmt f, receiver: nil, name: :y, args: []
      end
    end

    translate("x = 1 ? 2 : 3") do |ast|
      assert_block_stmt ast do |stmts|
        assert_if_stmt stmts[0] do |c, t, f|
          assert_value_stmt 1, c
          assert_value_stmt 2, t
          assert_value_stmt 3, f
        end
        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
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
          assert_if_stmt stmts[0] do |c, t, f|
            assert_call_stmt c, receiver: nil, name: :f, args: []
            assert_nil t
            assert_jump_stmt f, type: :break, args: []
          end
          assert_call_stmt stmts[1], receiver: nil, name: :g, args: []
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
          assert_if_stmt stmts[0] do |c, t, f|
            assert_call_stmt c, receiver: nil, name: :f, args: []
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
        assert_loop_stmt stmts[0]
        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
    end
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
      assert_if_stmt ast do |c, t, f|
        assert_value_stmt 1, c
        assert_value_stmt :self, t
        assert_nil f
      end
    end
  end

  def test_translate_or
    translate "1 || 2" do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_value_stmt 1, c
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

    translate "*, rhs = []" do |ast, node|
      assert_block_stmt ast do |stmts|
        assert_array_stmt stmts[0]

        assert_instance_of AST::Stmt::MAssign, stmts[1]
        assert_value stmts[0].dest, stmts[1].rhs
        assert_equal AST::Variable::Splat.new(var: nil), stmts[1].vars[0]
        assert_equal AST::Variable::Local.new(name: :rhs), stmts[1].vars[1]
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

  def test_translate_regexp
    translate '/hello#{1}, #{2}/i' do |ast|
      assert_block_stmt ast do |stmts|
        assert_value_stmt 1, stmts[0]
        assert_value_stmt 2, stmts[1]

        regexp = stmts[2]
        assert_instance_of AST::Stmt::Regexp, regexp
        assert_equal [:i], regexp.option
        assert_equal 4, regexp.content.size

        assert_value "hello", regexp.content[0]
        assert_value stmts[0].dest, regexp.content[1]
        assert_value ", ", regexp.content[2]
        assert_value stmts[1].dest, regexp.content[3]
      end
    end
  end

  def test_translate_range
    translate "1...2" do |ast|
      assert_instance_of AST::Stmt::Range, ast
      assert_value 1, ast.begin
      assert_value 2, ast.end
      assert_equal :exclusive, ast.type
    end

    translate "1..2" do |ast|
      assert_instance_of AST::Stmt::Range, ast
      assert_value 1, ast.begin
      assert_value 2, ast.end
      assert_equal :inclusive, ast.type
    end
  end

  def test_translate_dsym
    translate ':"#{test}="' do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :test, args: []

        assert_instance_of AST::Stmt::Dsym ,stmts[1]
        assert_equal 2, stmts[1].components.size
        assert_value stmts[0].dest, stmts[1].components[0]
        assert_value "=", stmts[1].components[1]
      end
    end
  end

  def test_translate_or_asgn
    translate "a ||= 3" do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_value_stmt AST::Variable::Local.new(name: :a), c
        assert_nil t
        assert_assign_stmt f, lhs: AST::Variable::Local.new(name: :a), rhs: 3
      end
    end

    translate "1.b ||= 3" do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_call_stmt c, receiver: 1, name: :b, args: []
        assert_nil t
        assert_call_stmt f, receiver: 1, name: :b=, args: [3]
      end
    end
  end

  def test_translate_and_asgn
    translate "a &&= 3" do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_value_stmt AST::Variable::Local.new(name: :a), c
        assert_assign_stmt t, lhs: AST::Variable::Local.new(name: :a), rhs: 3
        assert_nil f
      end
    end

    translate "1.b &&= 3" do |ast|
      assert_if_stmt ast do |c, t, f|
        assert_call_stmt c, receiver: 1, name: :b, args: []
        assert_call_stmt t, receiver: 1, name: :b=, args: [3]
        assert_nil f
      end
    end
  end

  def test_translate_opasgn
    translate "x += 1" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: AST::Variable::Local.new(name: :x), name: :+, args: [1]
        assert_assign_stmt stmts[1], lhs: AST::Variable::Local.new(name: :x), rhs: stmts[0].dest
      end
    end

    translate "1.f *= 2" do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: 1, name: :f, args: []
        assert_call_stmt stmts[1], receiver: stmts[0].dest, name: :*, args: [2]
        assert_call_stmt stmts[2], receiver: 1, name: :f=, args: [stmts[1].dest]
      end
    end
  end

  def test_translate_match_with_lasgn
    translate "/a/ =~ y" do |ast|
      assert_block_stmt ast do |stmts|
        assert_instance_of AST::Stmt::Regexp, stmts[0]
        assert_call_stmt stmts[1], receiver: nil, name: :y, args: []

        assert_instance_of AST::Stmt::MatchWithLasgn, stmts[2]
        assert_value stmts[0].dest, stmts[2].lhs
        assert_value stmts[1].dest, stmts[2].rhs
      end
    end
  end

  def test_translate_alias
    translate "alias a b" do |ast|
      assert_value_stmt :alias, ast
    end
  end

  def test_translate_xstr
    translate '`ls #{names}`' do |ast|
      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :names, args: []
        assert_instance_of AST::Stmt::Xstr, stmts[1]
        assert_value "ls ", stmts[1].components[0]
        assert_value stmts[0].dest, stmts[1].components[1]
      end
    end
  end

  def test_translate_for
    translate <<-EOS do |ast|
      for x in abc
        x + 1
      end
    EOS

      assert_block_stmt ast do |stmts|
        assert_call_stmt stmts[0], receiver: nil, name: :abc, args: []

        assert_instance_of AST::Stmt::For, stmts[1]
        assert_value AST::Variable::Local.new(name: :x), stmts[1].var
        assert_value stmts[0].dest, stmts[1].collection
        assert_call_stmt stmts[1].body, receiver: AST::Variable::Local.new(name: :x), name: :+, args: [1]
      end
    end
  end

  def test_case_when_splat
    translate <<-EOS do |ast|
      case 1
      when *[1,2,3]
        4
      end
    EOS
      assert_instance_of AST::Stmt::Case, ast

      assert_block_stmt ast.whens[0].pattern do |stmts|
        assert_array_stmt stmts[0], elements: [1,2,3]
        assert_value_stmt AST::Variable::Splat.new(var: stmts[0].dest), stmts[1]
      end

      assert_value_stmt 4, ast.whens[0].body
    end
  end

  def test_backref
    translate "a = $&" do |ast|
      assert_assign_stmt ast, lhs: AST::Variable::Local.new(name: :a), rhs: :back_ref
    end
  end
end
