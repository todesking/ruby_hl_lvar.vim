load File.join(File.dirname(__FILE__), "..", "plugin", "ruby-hl-lvar.vim")

describe RubyHlLvar::Extractor do
  let(:etor){ RubyHlLvar::Extractor.new }

  describe "#extract" do
    it 'with empty string' do
      etor.extract('').should be_empty
    end

    it "with simple assignment"
    it "with simple mass assignment like a, b, c = foo"
    it "with complex mass assignment like (a, (b, c)), d = foo"
    it "with simple block parameter like {|a, b| }"
    it "with complex block parameter like {|a, (b, c)| }"
    it "with simple method parameter"
    it "with method parameter like arg = 1"
    it "with method parameter like *args"
    it "with method parameter like arg: 1"
    it "with complex method parameter"
    it "with assignment in method definition"
    it "with assignment in nested control structure"
    it "with method definition in nested control structure"
  end
end
