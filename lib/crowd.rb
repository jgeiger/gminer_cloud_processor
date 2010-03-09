class Crowd
  include HTTParty
    format :json

  class << self

    def submit(action, params)
      inputs = params.is_a?(Array) ? params : [params]
      jobs_url = "#{CloudCrowd.config[:central_server]}/jobs"
      body = {:job => { 'action' => action, 'inputs' => inputs }.to_json}
      post(jobs_url, :body => body)
    end

  end # of self

end
