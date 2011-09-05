require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Geminabox do
  before do
    User.dataset.destroy
  end
  describe "/login" do
    it "renders a login form" do
      get "/login"
      last_response.should be_successful
      last_response.should have_tag "input#user_email"
      last_response.should have_tag "input#user_password"
    end
  end
  describe "/logout" do
    it "destroys the users session" do
      user = User.create(email: "a@a.com", password: "asdf1234")
      post '/authenticate', user: {email: "a@a.com", password: "asdf1234"}
      session['User'].should_not be_nil
      get '/logout'
      session['User'].should be_nil
    end
  end
  describe "/authenticate" do
    context "with valid params" do
      it "sets the users id in the session" do
        user = User.create(:email => "a@a.com", :password => "asdf1234")
        post "/authenticate", :user => {:email => "a@a.com", :password => "asdf1234"}
        session['User'].should == user.id
        last_response.should be_redirect
        get '/'
        last_response.body.should match "Upload Another Gem"
      end
    end
    context "with invalid params" do
      it "shows the login page" do
        post "/authenticate", :user => {:email => "asdf", :password => "asdf"}
        session['User'].should be_nil
        last_response.should be_redirect
      end
    end
  end
  describe "/register" do
    it "displays a registration form" do
      get '/register'
      last_response.should be_successful
      last_response.should have_tag "input#email"
      last_response.should have_tag "input#password"
      last_response.should have_tag "input#password_confirmation"
      last_response.should have_tag "input[type=submit][value=Register]"
    end
  end
  describe "/do_register" do
    context "with good params" do
      it "creates a new user" do
        post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: "asdf"
        User.find_by_email("a@a.com").should be_a User
      end
    end
    context "with bad params" do
      context "with no email" do
        it "renders the correct validation message" do
          post '/do_register', email: "", password: "asdf", password_confirmation: "asdf"
          last_response.should be_successful
          last_response.body.should match "email is required"
        end
      end
      context "with no password" do
        it "renders the correct validation mesage" do
          post '/do_register', email: "a@a.com", password: "", password_confirmation: "asdf"
          last_response.should be_successful
          last_response.body.should match "password does not match confirmation"
        end
      end
      context "with no password confirmation" do
        it "renders the correct validation message" do
          post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: ""
          last_response.should be_successful
          last_response.body.should match "password does not match confirmation"
        end
      end
      context "with an unmatched password confirmation" do
        it "renders the correct validation message" do
          post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: "asdf1234"
          last_response.should be_successful
          flash[:error].should match "password does not match confirmation"
          last_response.body.should match "password does not match confirmation"
        end
      end
    end
  end
  describe "/" do
    context "without logging in" do
    it "requires authentication" do
      get "/"
      last_response.should be_redirect
    end
    end
    context "after logging in" do
      before do
        @user = User.create(email: "a@a.com", password: "asdf")
        post '/authenticate', user: {email: "a@a.com", password: "asdf"}
      end
      it "renders the gem index" do
        get "/"
        last_response.should be_successful
        last_response.should match "Upload"
      end
    end
  end
end
