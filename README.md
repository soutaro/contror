# Contror

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/contror`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

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

TODO: Write usage instructions here

## Control Flow Graph

### Intermediate Language

Control flow graph is constructed from the following intermediate language.
Differences from Ruby are:

* Prohibit arbitrary expressions but variables some places
* If and whiles are statement, not an expression
* Introduces pseud variable; semantically a local variable, but not defined in source language

```rb
stmt ::= ()
       | stmt; ...
       | expr
       | a = expr
       | if expr then stmt else stmt end
       | while expr do stmt end
       | def f(x...) stmt end
       | class C < C stmt end
       | return a
       | break a
       | next a
       | retry a
       | begin stmt rescue stmt end

expr ::= 
       | a.f(a...)
       | a.f(a...) do stmt end
       | a
       | yield a...

a ::= x   # local variable
    | i   # pseud variable
    | @a  # instance variable
    | C   # constant
```

### Graph

Vertex of control flow graph is a `stmt` of the intermediate language.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/contror.

