class NCBOService
  include HTTParty
    base_uri 'rest.bioontology.org'
    format :xml

  class << self

    def current_ncbo_id(ncbo_id)
      begin
        result = NCBOService.get("/bioportal/virtual/ontology/#{ncbo_id}")
        bean = result['success']['data']['ontologyBean']
        name = bean['displayLabel']
        version = bean['versionNumber']
        id = bean['id']
        [id, name, version]
      rescue Exception => e
        puts "#{e.inspect} -- #{e.message}"
        raise NCBOException.new('ontology update error', ncbo_id)
      end
    end

    def get_data(text, stopwords, ncbo_ontology_id=nil)
      retried = false
      parameters = {
        "longestOnly" => "false",
        "wholeWordOnly" => "true",
        "stopWords" => stopwords,
        "minTermSize" => "2",
        "withSynonyms" => "false",
        "scored" => "true",
        "ontologiesToExpand" => "#{ncbo_ontology_id}",
        "isVirtualOntologyId" => "true",
        "levelMax" => "10",
        "textToAnnotate"  => "#{text}",
        "format" => "xml"
      }

      parameters.merge!({"ontologiesToKeepInResult" => "#{ncbo_ontology_id}"}) if ncbo_ontology_id

      begin
        data = NCBOService.post("/obs/annotator", :body => parameters)
      rescue EOFError, Errno::ECONNRESET
        raise NCBOException.new('too many connection resets', parameters) if retried
        retried = true
        retry
      rescue Timeout::Error
        raise NCBOException.new('consecutive timeout errors', parameters) if retried
        retried = true
        retry
      rescue Exception => e
        raise NCBOException.new('invalid XML error', parameters) if retried
        retried = true
        retry
      end
    end

    def result_hash(text, stopwords, ncbo_ontology_id)
      result = NCBOService.get_data(text, stopwords, ncbo_ontology_id)
      if result && result['success']
        annotations = result['success']['data']['annotatorResultBean']['annotations']
        return NCBOService.generate_hash(annotations)
      elsif result && result['errorStatus']
        raise NCBOException.new(result['errorStatus']['shortMessage'], result['errorStatus']['longMessage'])
      else
        raise NCBOException.new("Unknown NCBO Error", result)
      end
    end

    def generate_hash(annotations)
      hash = {"MGREP" => {}, "ISA_CLOSURE" => {}, "MAPPING" => {}}
      if annotations && annotations.any?
        bean = annotations["annotationBean"]
        annotation_array = bean.is_a?(Hash) ? [bean] : bean
        hash = annotation_array.inject({"MGREP" => {}, "ISA_CLOSURE" => {}, "MAPPING" => {}}) do |h, annotation|
          concept = annotation["concept"]
          context = annotation["context"]
          h = NCBOService.classify_results(concept, context, h)
          h
        end
      end
      hash
    end

    def classify_results(concept, context, h)
      if context["contextName"] == "MGREP"
        h["MGREP"][concept["localConceptId"].gsub("/","|")] = {:name => concept["preferredName"], :from => context["from"], :to => context["to"]}
      elsif context["contextName"] == "MAPPING"
        # mapping will be treated/processed the same as an mgrep, but with the from,to set to 0 since we can't reference it in the text anyway
        h["MAPPING"][concept["localConceptId"].gsub("/","|")] = {:name => concept["preferredName"], :from => "0", :to => "0"}
      else
        if h["ISA_CLOSURE"][context['concept']["localConceptId"].gsub("/","|")].is_a?(Array)
          h["ISA_CLOSURE"][context['concept']["localConceptId"].gsub("/","|")] << {:name => concept["preferredName"], :id => concept["localConceptId"].gsub("/","|")}
        else
          h["ISA_CLOSURE"][context['concept']["localConceptId"].gsub("/","|")] = [{:name => concept["preferredName"], :id => concept["localConceptId"].gsub("/","|")}]
        end
      end
      h
    end

  end # of class << self

end
