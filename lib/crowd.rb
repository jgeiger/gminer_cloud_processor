class Crowd
  include HTTParty
    format :json

  class << self

    def submit(action, params)
      host = 'http://localhost:9173/jobs'
      body = {:job => { 'action' => action, 'inputs' => [params] }.to_json}
      post(host, :body => body)
    end

  end # of self

end
