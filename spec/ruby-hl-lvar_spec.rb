load File.join(File.dirname(__FILE__), "..", "plugin", "ruby-hl-lvar.vim")

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

    context "with top level" do
      context "with simple assignment" do
        it { 'a = 1'.should_extract_to [["a", 1, 0]] }
      end
      context "with simple mass assignment" do
        it {
          'a, b, c = foo'.should_extract_to [["a", 1, 0], ["b", 1, 3], ["c", 1, 6] ]
        }
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

      context "bare lvar reference"
      context "lvar reference in method call lhs"
      context "lvar reference in method call argument"
      context "lvar reference in block"
      context "lvar reference in method body"
      context "lvar reference in method class body"
      context "lvar reference in method module body"
      context "method reference in expr should ignored"

      it "with complex block parameter like {|a, (b, c)| }"
      it "with multi assignment like a = b = c"
      it "with assignment in rhs"
      it "with assignment in method call"
    end

    context "with method definition" do
      it "with simple method parameter"
      it "with method parameter like arg = 1"
      it "with method parameter like *args"
      it "with method parameter like arg: 1"
      it "with complex method parameter"
      it "with assignment in method definition"
    end

    context "with complex control structure" do
      it "with assignment"
      it "with method definition"
    end

    context "with string interporlation"
  end
end
