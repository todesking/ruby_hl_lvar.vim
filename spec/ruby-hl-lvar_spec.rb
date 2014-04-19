load File.join(File.dirname(__FILE__), "..", "plugin", "ruby-hl-lvar.vim")

describe RubyHlLvar::Extractor do
  let(:etor){ RubyHlLvar::Extractor.new }

  describe "#extract" do
    it 'with empty string' do
      etor.extract('').should be_empty
    end

    context "with top level" do
      context "with simple assignment" do
        it { etor.extract('a = 1').should == [["a", 1, 0]] }
      end
      it "with simple mass assignment like a, b, c = foo"
      it "with complex mass assignment like (a, (b, c)), d = foo"
      it "with simple block parameter like {|a, b| }"
      it "with complex block parameter like {|a, (b, c)| }"
    end

    context "with rhs of assignment"

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
