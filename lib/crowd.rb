class Crowd
  include HTTParty
    format :json

  class << self

    def submit(action, params)
      jobs_url = "#{CloudCrowd.config[:central_server]}/jobs"
      body = {:job => { 'action' => action, 'inputs' => [params] }.to_json}
      post(jobs_url, :body => body)
    end

  end # of self

end
