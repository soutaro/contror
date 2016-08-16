require_relative 'test_helper'

class ANFTranslatorTest < Minitest::Test
  def translate(source)
    node = parse(source)
    translator = Contror::ANF::Translator.new
    stmt = translator.translate(node: node)

    yield stmt, node
  end

  AST = Contror::ANF::AST

  def test_translate_lasign
    translate("x = 3") do |ast|
      assert_instance_of AST::Stmt::Assign, ast

      assert_instance_of AST::Variable::Local, ast.var
      assert_equal :x, ast.var.name

      assert_instance_of AST::Expr::Value, ast.expr
      assert_equal :int, ast.expr.node.type
    end
  end

  def test_translate_call
    translate("1 + 2") do |ast|
      assert_instance_of AST::Stmt::Expr, ast

      expr = ast.expr

      assert_instance_of AST::Expr::Call, expr
      assert_instance_of AST::Expr::Value, expr.receiver
      assert_equal :+, expr.name
      assert_instance_of AST::Expr::Value, expr.args[0]
    end
  end

  def test_translate_call_normalizing_receiver
    translate("1+2+3") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # _1 = 1+2
      assign = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, assign
      assert_instance_of AST::Variable::Pseud, assign.var
      assert_instance_of AST::Expr::Call, assign.expr

      # _1+3
      call = ast.stmts[1]
      assert_instance_of AST::Stmt::Expr, call
      assert_instance_of AST::Expr::Call, call.expr
      assert_instance_of AST::Expr::Var, call.expr.receiver
      assert_instance_of AST::Variable::Pseud, call.expr.receiver.var
      assert_equal assign.var, call.expr.receiver.var
    end
  end

  def test_translate_call_normalizing_args
    translate("f(1+2)") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # _1 = 1+2
      assign = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, assign
      assert_instance_of AST::Variable::Pseud, assign.var
      assert_instance_of AST::Expr::Call, assign.expr

      # f(_1)
      call = ast.stmts[1]
      assert_instance_of AST::Stmt::Expr, call
      assert_instance_of AST::Expr::Call, call.expr

      arg = call.expr.args[0]
      assert_instance_of AST::Expr::Var, arg
      assert_instance_of AST::Variable::Pseud, arg.var

      assert_equal assign.var, arg.var
    end
  end

  def test_translate_literals
    translate("f(1, 1.0, 'a', :b, true, false, self, nil, 1i, 1r)") do |ast|
      assert_instance_of AST::Stmt::Expr, ast
      assert_instance_of AST::Expr::Call, ast.expr
    end
  end

  def test_translate_array
    translate("[1, true, false, nil]") do |ast|
      assert_instance_of AST::Stmt::Expr, ast
      assert_instance_of AST::Expr::Array, ast.expr

      ast.expr.elements.each do |elem|
        assert_instance_of AST::Expr::Value, elem
      end
    end

    translate("[@a]") do |ast|
      assert_instance_of AST::Stmt::Expr, ast
      assert_instance_of AST::Expr::Array, ast.expr

      iv = ast.expr.elements.first
      assert_instance_of AST::Expr::Var, iv
      assert_equal :"@a", iv.var.name
    end

    # array elements should be value
    translate("[f()]") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # _1 = f()
      assign = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, assign
      assert_instance_of AST::Variable::Pseud, assign.var
      assert_instance_of AST::Expr::Call, assign.expr
      assert_equal :f, assign.expr.name

      # [_1]
      array = ast.stmts[1]
      assert_instance_of AST::Stmt::Expr, array
      assert_instance_of AST::Expr::Array, array.expr
      assert_instance_of AST::Expr::Var, array.expr.elements[0]
      assert_equal assign.var, array.expr.elements[0].var
    end
  end

  def test_translate_if
    src = <<-EOS
      if a
        b
      else
        c
      end
    EOS
    translate(src) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assert_instance_of AST::Stmt::Assign, ast.stmts[0]

      if_stmt = ast.stmts[1]
      assert_instance_of AST::Stmt::If, if_stmt
      assert_instance_of AST::Expr::Var, if_stmt.condition
      assert_instance_of AST::Stmt::Expr, if_stmt.then_clause
      assert_instance_of AST::Stmt::Expr, if_stmt.else_clause
    end
  end

  def test_translate_if_expr
    translate("f(1 ? y : z)") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      if_stmt = ast.stmts[0]
      assert_instance_of AST::Stmt::If, if_stmt

      condition = if_stmt.condition
      assert_instance_of AST::Expr::Value, condition
      assert_equal 1, condition.node.children[0]

      # _1 = y()
      then_clause = if_stmt.then_clause
      assert_instance_of AST::Stmt::Assign, then_clause
      assert_instance_of AST::Variable::Pseud, then_clause.var
      assert_instance_of AST::Expr::Call, then_clause.expr
      assert_equal :y, then_clause.expr.name

      # _1 = z
      else_clause = if_stmt.else_clause
      assert_instance_of AST::Stmt::Assign, else_clause
      assert_instance_of AST::Variable::Pseud, else_clause.var
      assert_instance_of AST::Expr::Call, else_clause.expr
      assert_equal :z, else_clause.expr.name

      assert_equal then_clause.var, else_clause.var

      # _2 = _1
      assignment = ast.stmts[1]
      assert_instance_of AST::Stmt::Assign, assignment
      assert_instance_of AST::Variable::Pseud, assignment.var
      assert_instance_of AST::Expr::Var, assignment.expr

      assert_equal then_clause.var, assignment.expr.var
      refute_equal then_clause.var, assignment.var

      # f(_2)

      call_stmt = ast.stmts[2]
      assert_instance_of AST::Stmt::Expr, call_stmt

      call_expr = call_stmt.expr
      assert_instance_of AST::Expr::Call, call_expr
      assert_equal :f, call_expr.name
      assert_instance_of AST::Expr::Var, call_expr.args[0]
      assert_equal assignment.var, call_expr.args[0].var
    end
  end

  def test_translate_while
    source = <<-EOS
      while true
        puts 1
      end
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::While, ast

      assert_nil ast.break_var

      cond = ast.condition
      assert_instance_of AST::Stmt::Expr, cond
      assert_instance_of AST::Expr::Value, cond.expr
      assert_equal :true, cond.expr.node.type

      body = ast.body
      assert_instance_of AST::Stmt::Expr, body
      assert_instance_of AST::Expr::Call, body.expr
      assert_equal :puts, body.expr.name
    end
  end

  def test_translate_while_expr
    source = <<-EOS
      a = while true
          end
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      while_stmt = ast.stmts[0]
      assert_instance_of AST::Stmt::While, while_stmt
      refute_nil while_stmt.break_var

      assign_stmt = ast.stmts[1]
      assert_instance_of AST::Stmt::Assign, assign_stmt
      assert_instance_of AST::Variable::Local, assign_stmt.var
      assert_instance_of AST::Expr::Var, assign_stmt.expr
      assert_instance_of AST::Variable::Pseud, assign_stmt.expr.var

      assert_equal while_stmt.break_var, assign_stmt.expr.var
    end
  end

  def test_local_variable
    source = <<-EOS
      a = 1
      x = a
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assignment1 = ast.stmts.first
      assert_instance_of AST::Stmt::Assign, assignment1
      assert_instance_of AST::Variable::Local, assignment1.var
      assert_equal :a, assignment1.var.name

      assignment2 = ast.stmts.last
      assert_instance_of AST::Stmt::Assign, assignment2
      assert_instance_of AST::Variable::Local, assignment2.expr.var
      assert_equal :a, assignment2.expr.var.name
    end
  end

  def test_instance_variable
    source = <<-EOS
      @a = 1
      x = @a
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assignment1 = ast.stmts.first
      assert_instance_of AST::Stmt::Assign, assignment1
      assert_instance_of AST::Variable::Instance, assignment1.var
      assert_equal :"@a", assignment1.var.name

      assignment2 = ast.stmts.last
      assert_instance_of AST::Stmt::Assign, assignment2
      assert_instance_of AST::Variable::Instance, assignment2.expr.var
      assert_equal :"@a", assignment2.expr.var.name
    end
  end

  def test_global_variable
    source = <<-EOS
      $a = 2
      _ = $a
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assignment1 = ast.stmts.first
      assert_instance_of AST::Stmt::Assign, assignment1
      assert_instance_of AST::Variable::Global, assignment1.var
      assert_equal :"$a", assignment1.var.name

      assignment2 = ast.stmts.last
      assert_instance_of AST::Stmt::Assign, assignment2
      assert_instance_of AST::Variable::Global, assignment2.expr.var
      assert_equal :"$a", assignment2.expr.var.name
    end
  end

  def test_class_variable
    source = <<-EOS
      @@a = 2
      _ = @@a
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assignment1 = ast.stmts.first
      assert_instance_of AST::Stmt::Assign, assignment1
      assert_instance_of AST::Variable::Class, assignment1.var
      assert_equal :"@@a", assignment1.var.name

      assignment2 = ast.stmts.last
      assert_instance_of AST::Stmt::Assign, assignment2
      assert_instance_of AST::Variable::Class, assignment2.expr.var
      assert_equal :"@@a", assignment2.expr.var.name
    end
  end

  def test_constant
    source = <<-EOS
      C = 3
      _ = C
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      assignment1 = ast.stmts.first
      assert_instance_of AST::Stmt::ConstantAssign, assignment1

      assignment2 = ast.stmts.last
      assert_instance_of AST::Stmt::Assign, assignment2

      const_expr = assignment2.expr
      assert_instance_of AST::Expr::Constant, const_expr
      assert_nil const_expr.prefix
      assert_equal :C, const_expr.name
    end
  end

  def test_nested_constant
    source = <<-EOS
      A::B::C = 3
      _ = A::B::C
    EOS

    translate(source) do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # _1 = A
      lookup_a = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, lookup_a
      assert_instance_of AST::Variable::Pseud, lookup_a.var
      assert_instance_of AST::Expr::Constant, lookup_a.expr
      assert_nil lookup_a.expr.prefix
      assert_equal :A, lookup_a.expr.name

      # _2 = _1::B
      lookup_b = ast.stmts[1]
      assert_instance_of AST::Stmt::Assign, lookup_b
      assert_instance_of AST::Variable::Pseud, lookup_b.var
      assert_instance_of AST::Expr::Constant, lookup_b.expr
      assert_instance_of AST::Expr::Var, lookup_b.expr.prefix
      assert_equal lookup_a.var, lookup_b.expr.prefix.var
      assert_equal :B, lookup_b.expr.name

      # _3::C = C
      assign_c = ast.stmts[2]
      assert_instance_of AST::Stmt::ConstantAssign, assign_c
      assert_instance_of AST::Expr::Var, assign_c.prefix
      assert_equal lookup_b.var, assign_c.prefix.var
      assert_equal :C, assign_c.name
      assert_instance_of AST::Expr::Value, assign_c.expr
      assert_equal 3, assign_c.expr.node.children.first

      # _4 = A
      lookup_a2 = ast.stmts[3]
      assert_instance_of AST::Stmt::Assign, lookup_a2
      assert_instance_of AST::Variable::Pseud, lookup_a2.var
      assert_instance_of AST::Expr::Constant, lookup_a2.expr
      assert_nil lookup_a2.expr.prefix
      assert_equal :A, lookup_a2.expr.name

      # _5 = _4::B
      lookup_b2 = ast.stmts[4]
      assert_instance_of AST::Stmt::Assign, lookup_b2
      assert_instance_of AST::Variable::Pseud, lookup_b2.var
      assert_instance_of AST::Expr::Constant, lookup_b2.expr
      assert_instance_of AST::Expr::Var, lookup_b2.expr.prefix
      assert_equal lookup_a2.var, lookup_b2.expr.prefix.var
      assert_equal :B, lookup_b2.expr.name

      # _ = _5::C
      assignment = ast.stmts[5]
      assert_instance_of AST::Stmt::Assign, assignment
      assert_instance_of AST::Variable::Local, assignment.var
      assert_equal :_, assignment.var.name
      assert_instance_of AST::Expr::Constant, assignment.expr
      assert_instance_of AST::Expr::Var, assignment.expr.prefix
      assert_equal lookup_b2.var, assignment.expr.prefix.var
      assert_equal :C, assignment.expr.name
    end
  end

  def test_assignment_expr
    translate("a = @b = $c = @@d = true") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # @@d = true
      assign_d = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, assign_d
      assert_equal :"@@d", assign_d.var.name

      # _1 = @@d
      propagation_d = ast.stmts[1]
      assert_instance_of AST::Stmt::Assign, propagation_d
      assert_instance_of AST::Variable::Pseud, propagation_d.var
      assert_instance_of AST::Expr::Var, propagation_d.expr
      assert_equal :"@@d", propagation_d.expr.var.name

      # $c = _1
      assign_c = ast.stmts[2]
      assert_instance_of AST::Stmt::Assign, assign_c
      assert_equal :"$c", assign_c.var.name
      assert_instance_of AST::Expr::Var, assign_c.expr
      assert_equal propagation_d.var, assign_c.expr.var

      # _2 = $c
      propagation_c = ast.stmts[3]
      assert_instance_of AST::Stmt::Assign, propagation_c
      assert_instance_of AST::Variable::Pseud, propagation_c.var
      assert_instance_of AST::Expr::Var, propagation_c.expr
      assert_equal :"$c", propagation_c.expr.var.name

      # @b = _2
      assign_b = ast.stmts[4]
      assert_instance_of AST::Stmt::Assign, assign_b
      assert_equal :"@b", assign_b.var.name
      assert_instance_of AST::Expr::Var, assign_b.expr
      assert_equal propagation_c.var, assign_b.expr.var

      # _3 = @b
      propagation_b = ast.stmts[5]
      assert_instance_of AST::Stmt::Assign, propagation_b
      assert_instance_of AST::Variable::Pseud, propagation_b.var
      assert_instance_of AST::Expr::Var, propagation_b.expr
      assert_equal :"@b", propagation_b.expr.var.name

      # a = _3
      assign_a = ast.stmts[6]
      assert_instance_of AST::Stmt::Assign, assign_a
      assert_equal :a, assign_a.var.name
      assert_instance_of AST::Expr::Var, assign_a.expr
      assert_equal propagation_b.var, assign_a.expr.var

      assert_nil ast.stmts[7]
    end
  end

  def test_assignment_constant
    translate("_ = C = f()") do |ast|
      assert_instance_of AST::Stmt::Block, ast

      # _1 = f()
      propagate_f = ast.stmts[0]
      assert_instance_of AST::Stmt::Assign, propagate_f
      assert_instance_of AST::Expr::Call, propagate_f.expr
      assert_instance_of AST::Variable::Pseud, propagate_f.var

      # C = _1
      assign_c = ast.stmts[1]
      assert_instance_of AST::Stmt::ConstantAssign, assign_c
      assert_equal :C, assign_c.name
      assert_instance_of AST::Expr::Var, assign_c.expr
      assert_equal propagate_f.var, assign_c.expr.var

      # _2 = _1
      propagate_c = ast.stmts[2]
      assert_instance_of AST::Stmt::Assign, propagate_c
      assert_instance_of AST::Variable::Pseud, propagate_c.var
      assert_instance_of AST::Expr::Var, propagate_c.expr
      assert_equal propagate_f.var, propagate_c.expr.var

      # _ = _2
      assign = ast.stmts[3]
      assert_instance_of AST::Stmt::Assign, assign
      assert_instance_of AST::Variable::Local, assign.var
      assert_equal :_, assign.var.name
      assert_instance_of AST::Expr::Var, assign.expr
      assert_equal propagate_c.var, assign.expr.var

      assert_nil ast.stmts[4]
    end
  end

  def test_translate_def
    translate("def f(); 3; end") do |ast|
      p ast
    end
  end

  def test_translate_def_without_body

  end

  def test_translate_def_with_params

  end

  def test_translate_def_with_defaulted_params

  end
end
