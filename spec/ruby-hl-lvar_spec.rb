require 'pry'
load File.join(File.dirname(__FILE__), "..", "autoload", "ruby_hl_lvar.vim.rb")

class String
  def should_extract_to(expected)
    RubyHlLvar::Extractor.new.extract(self).should == expected
  end
end

describe RubyHlLvar::Extractor do
  let(:etor){ RubyHlLvar::Extractor.new }

  describe "#extract" do
    it 'with empty string' do
      etor.extract('').should be_empty
    end

    context "with simple assignment" do
      it { 'a = 1'.should_extract_to [["a", 1, 0]] }
    end
    context "with simple mass assignment" do
      it {
        'a, b, c = foo'.should_extract_to [["a", 1, 0], ["b", 1, 3], ["c", 1, 6] ]
      }
    end

    context 'complex mass assignment' do
      it { 'a, (b, c) = foo'.should_extract_to [['a', 1, 0], ['b', 1, 4], ['c', 1, 7]] }
      it { 'a, *b = foo'.should_extract_to [['a', 1, 0], ['b', 1, 4]] }
    end

    context "lhs of assignment" do
      it { "a = 1\nb = a".should_extract_to [["a", 1, 0], ["b", 2, 0], ["a", 2, 4]] }
      it { "a = 1\n(a, b) = a".should_extract_to [["a", 1, 0], ["a", 2, 1], ["b", 2, 4], ["a", 2, 9]] }
    end

    context "with complex mass assignment" do
      it { '(a, (b, c)), d = foo'.should_extract_to [["a", 1, 1], ["b", 1, 5], ["c", 1, 8], ["d", 1, 13]] }
    end

    context "with simple block({ ... }) parameter like {|a, b| }" do
      it { "foo {|a, b| }".should_extract_to [["a", 1, 6], ["b", 1, 9]] }
    end
    context "with simple block({ ... }) without args" do
      it { "foo { }".should_extract_to [] }
    end
    context "with simple block(do ... end) without args" do
      it { "foo { }".should_extract_to [] }
    end
    context "with simple block(do ... end) parameter" do
      it { "foo do|a|; end".should_extract_to [["a", 1, 7]] }
    end
    context "complex block args" do
      it { "foo {|(a,(b,c))| }".should_extract_to [["a", 1, 7], ["b", 1, 10], ["c", 1, 12]] }
    end
    context "with lvar reference in block body" do
      it { "foo {|x| x}".should_extract_to [["x", 1, 6], ["x", 1, 9]] }
    end
    context "array" do
      it { "a,b=x\n[a,b,c]".should_extract_to [["a", 1, 0], ["b", 1, 2], ["a", 2, 1], ["b", 2, 3]] }
    end

    context "bare lvar reference" do
      it { "x = 1; y; x".should_extract_to [["x", 1, 0], ["x", 1, 10]] }
    end

    context "lvar reference in binop" do
      it { "x = 1; x + y".should_extract_to [["x", 1, 0], ["x", 1, 7]] }
    end
    context "lvar reference in method call lhs"
    context "lvar reference in method call argument with ()" do
      it { "x=1\nfoo(x,y,z)".should_extract_to [["x", 1, 0], ["x", 2, 4]] }
    end
    context "method call with no args" do
      it { "foo()".should_extract_to [] }
      it { "foo".should_extract_to [] }
    end
    context "block with no args" do
      it { "foo(){}".should_extract_to [] }
      it { "foo {}".should_extract_to [] }
    end
    context "lvar reference in method call argument without ()" do
      it { "x=1\nfoo x,y,z".should_extract_to [["x", 1, 0], ["x", 2, 4]] }
    end
    context "lvar reference in block"
    context "lvar reference in method body" do
      it { "def foo\nx=1\nend".should_extract_to [["x", 2, 0]] }
    end
    context "lvar reference in singleton body" do
      it { "def x.foo\nx=1\nend".should_extract_to [["x", 2, 0]] }
    end
    context "lvar reference in class body" do
      it { "class A\nx = 10\nend".should_extract_to [["x", 2, 0]] }
    end
    context "lvar reference in method module body"
    context "method reference in expr should ignored"

    context "lvar reference in module definition" do
      it { "module A;\nx = 1;\nx; end".should_extract_to [["x", 2, 0], ["x", 3, 0]] }
    end

    context "string literal" do
      it { "x=0\n\"x\#{x}x\"".should_extract_to [["x", 1, 0], ["x", 2, 4]] }
    end

    context "method params" do
      it { "def f(x)\nx\nend".should_extract_to [["x", 1, 6], ["x", 2, 0]] }
      it { "def f(*x)\nx\nend".should_extract_to [["x", 1, 7], ["x", 2, 0]] }
      it { "def f(x=0)\nx\nend".should_extract_to [["x", 1, 6], ["x", 2, 0]] }
      it { "def f(&x)\nx\nend".should_extract_to [["x", 1, 7], ["x", 2, 0]] }
    end

    context "method_arg" do
      it { "x=10;\nfoo(x)".should_extract_to [["x", 1, 0], ["x", 2, 4]] }
      it { "x=10;\na.b(x)".should_extract_to [["x", 1, 0], ["x", 2, 4]] }
    end

    context "field mass assignment" do
      it { "x.y, z = 1, 2".should_extract_to [["z", 1, 5]] }
    end
    context "ivar mass assignment" do
      it { "@a, @b = 1, 2".should_extract_to [] }
    end

    context "+=" do
      it { "a += 1".should_extract_to [["a", 1, 0]] }
    end

    context "rescue variable" do
      it { "begin\nrescue => e\nend".should_extract_to [["e", 2, 10]]}
      it { "begin\nrescue => e\ne\nend".should_extract_to [["e", 2, 10], ["e", 3, 0]]}
      it { "begin\nrescue => e1\nrescue => e2\nend".should_extract_to [["e1", 2, 10], ["e2", 3, 10]]}
    end
  end
end
