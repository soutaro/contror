module ANFAssertions
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

  def assert_if_stmt(stmt, condition:)
    assert_instance_of AST::Stmt::If, stmt
    assert_value condition, stmt.condition
    yield stmt.then_clause, stmt.else_clause if block_given?
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

  def assert_array_stmt(stmt, elements: nil)
    assert_instance_of AST::Stmt::Array, stmt

    if elements
      assert_equal elements.size, stmt.elements.size
      stmt.elements.each.with_index do |a, i|
        assert_value elements[i], a
      end
    end

    yield stmt.elements if block_given?
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

  def assert_def_stmt(stmt, object:, name:)
    assert_instance_of AST::Stmt::Def, stmt
    assert_value object, stmt.object
    assert_equal name, stmt.name
    yield stmt.params, stmt.body if block_given?
  end

  def assert_class_stmt(stmt, name:, super_class:)
    assert_instance_of AST::Stmt::Class, stmt

    assert_value name, stmt.name
    assert_value super_class, stmt.super_class

    yield stmt.body if block_given?
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
