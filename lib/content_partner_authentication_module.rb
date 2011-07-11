module ContentPartnerAuthenticationModule
    
  # Protected authentication methods
  # ------------------------------------

  def agent_logged_in?
    current_agent.class == Agent
  end

  # Accesses the current agent from the session
  def current_agent
    @current_agent ||= (agent_login_from_session || agent_login_from_cookie) unless @current_agent == false
  end

  # Store the given agent id in the session
  def current_agent=(new_agent)
    session[:agent_id] = new_agent.is_a?(Agent) ? new_agent.id : nil
    @current_agent = new_agent || false
  end

  def agent_login_required
    agent_logged_in? || agent_access_denied
  end

  def agent_access_denied
    agent_store_location
    redirect_to url_for(:controller=>'/content_partner',:action => 'login')
  end

  def agent_store_location
    session[:agent_return_to] = url_for(:controller=>controller_name, :action=>action_name) # request.request_uri
  end

  def agent_login_from_session
    self.current_agent = Agent.find_by_id(session[:agent_id]) if session[:agent_id]
  end

  def agent_login_from_cookie
    agent = cookies[:agent_auth_token] && Agent.find_by_remember_token(cookies[:agent_auth_token])
    if agent && agent.remember_token?
      cookies[:agent_auth_token] = { :value => agent.remember_token, :expires => agent.remember_token_expires_at }
      self.current_agent = agent
    end
  end

  def agent_redirect_back_or_default(default)
    redirect_to(session[:agent_return_to] || default, :protocol => 'http://')
    session[:agent_return_to] = nil
  end

  def is_user_admin?
    current_user.is_admin?
  end

  def agent_must_be_agreeable
    unless current_agent.ready_for_agreement?
      redirect_to :action => 'index', :controller => '/content_partner'
    end
  end

  def resource_must_belong_to_agent(specific_resource = nil)
    belongs_to_agent = false
    @curr_obj = current_object.nil? ? specific_resource : current_object
    if @curr_obj
      Agent.with_master do
        if params[:id] && @curr_obj.agents.include?(current_agent)
          belongs_to_agent = true
        end
      end
    end
    if !belongs_to_agent
      flash[:notice]='The resource you selected is invalid.'
      redirect_to :controller=>'resources',:action=>'index'
    end
  end

end
