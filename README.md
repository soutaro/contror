# Contror - Control Flow Graph of Ruby Programs

Contror builds intra-procedural control flow graph of Ruby programs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'contror'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install contror

## Usage

```rb
require 'parser/current'
require 'contror'

# Recommended: for extra precision on lambda (->)
Parser::Builders::Default.emit_lambda = true

node = Parser::CurrentRuby.parse(your_ruby_code)
stmt = Contror::ANF::Translator.new.translate(node: node)
graph_builder = Contror::Graph::Builder.new(stmt: stmt)

graph_builder.each_graph do |graph|
  # Do anything you want with control flow graph
end
```

## Graph Construction

Graph construction is done in two steps:

1. Translate `Parser::AST::Node` to `Contror::ANF::AST::Stmt`
2. Construct control flow graph from `Contror::ANF::AST::Stmt`

### ANF

Visit Wikipedia for more about ANF: https://en.wikipedia.org/wiki/A-normal_form

ANF does not allow having non-value expressions as method call arguments.
Value expression in Ruby is one of

1. Literal
2. Variables (but not constant)
3. `defined?` and `alias`
3. Some special variable like expressions including `self`, and `$1`

Non-value expression is an expression which is not a value expression.

#### Example

The following Ruby program is not an ANF.

```ruby
z = 1 + 2 + f(0)
```

The equivalent ANF will be like the following:

```ruby
_0 = 1 + 2
_1 = f(0)
z = _0 + _1
```

Here, `_0` and `_1` are pseudo variable introduced during ANF translation.

### Control Flow Graph

Control flow graph construction from ANF is almost trivial; put edges between ANF constructs.

Contror generates graphs against:

* The statement specified as `.new(stmt:)`
* Method definitions

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

The repo includes `bin/contror` command for testing and experiments:

```
bin/contror parse lib/contror                  # Try to parse given ruby scripts and translate them to ANF
bin/contror anf lib/contror/graph/builder.rb   # Print ANF
bin/contror dot lib/contror/graph/builder.rb   # Print contror flow graph as DOT
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/contror.
