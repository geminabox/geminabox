require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe User do
  before do
    User.dataset.destroy
  end
  describe ".find_by_email" do
    context "the user exists" do
      it "returns a user object" do
        db_user = User.create(:email => "a@a.com", :password => "asdf")
        user = User.find_by_email("a@a.com")
        user.should be_a User
        user.email.should == "a@a.com"
      end
    end
    context "the user does not exist" do
      it "returns nil" do
        User.find_by_email("a@a.com").should be_nil
      end
    end
  end

  describe ".create" do
    it "returns the newly created user" do
      user = User.create(:email => "a@a.com", :password => "asdf")
      user.should be_a User
      user.email.should == "a@a.com"
    end
    it "persists a new user" do
      user = User.create(:email => "a@a.com", :password => "asdf")
      User.find_by_email(user.email).should == user
    end
  end

  describe ".new" do
    it "returns a user object" do
      user = User.new
      user.should be_a User
    end
    context "with attributes" do
      it "sets them on the returned object" do
        user = User.new(:email => "a@a.com")
        user.email.should == "a@a.com"
      end
    end
  end

  describe "validations" do
    it "requires an email" do
      user = User.new(:password => "asdf")
      user.should_not be_valid
    end
    it "requires a password" do
      user = User.new(:email => "a@a.com")
      user.should_not be_valid
    end
  end
end
