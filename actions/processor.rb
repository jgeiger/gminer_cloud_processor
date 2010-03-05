require File.dirname(__FILE__) + '/support/setup'

class Processor < CloudCrowd::Action

  def process
    process_job(input)
  end

  def process_job(params)
    Crowd.submit('scheduler', {'command' => 'working', 'job_id' => params['job_id'], 'time' => Time.now.to_f})
    # params = {'job_id' => job.id, 'geo_accession' => job.geo_accession, 'field' => job.field, 'value' => item.send(job.field), 'description' => item.descriptive_text, 'ncbo_id' => ncbo_id, 'stopwords' => stopwords}
    create_for(params['geo_accession'], params['field'], params['value'], params['description'], params['ncbo_id'], params['stopwords'], params['email'])
    Crowd.submit('scheduler', {'command' => 'finished', 'job_id' => params['job_id'], 'time' => Time.now.to_f})
    rescue NCBOException => ex
      Crowd.submit('scheduler', {'command' => 'failed', 'job_id' => params['job_id']})
  end

  def create_for(geo_accession, field_name, field_value, description, ncbo_id, stopwords, email)
    cleaned = field_value.gsub(/[\r\n]+/, " ")
    hash = NCBOService.result_hash(cleaned, stopwords, email, ncbo_id)
    process_ncbo_results(hash, geo_accession, field_name, description, ncbo_id)
  end

  def process_ncbo_results(hash, geo_accession, field_name, description, ncbo_id)
    process_direct(hash["MGREP"], geo_accession, field_name, description, ncbo_id)
    process_direct(hash["MAPPING"], geo_accession, field_name, description, ncbo_id)
    process_closure(hash["ISA_CLOSURE"], geo_accession, field_name, ncbo_id)
  end

  def process_direct(hash, geo_accession, field_name, description, ncbo_id)
    if hash.keys.any?
      hash.keys.each do |key|
        current_ncbo_id, term_id = key.split("|")
        save_term('term_id' => "#{ncbo_id}|#{term_id}", 'ncbo_id' => ncbo_id, 'term_name' => hash[key][:name])
        save_annotation('geo_accession' => geo_accession, 'field_name' => field_name, 'ncbo_id' => ncbo_id, 'ontology_term_id' => "#{ncbo_id}|#{term_id}", 'text_start' => hash[key][:from], 'text_end' => hash[key][:to], 'description' => description)
      end
    else
      save_annotation('geo_accession' => geo_accession, 'field_name' => field_name, 'ncbo_id' => "none", 'ontology_term_id' => "none", 'text_start' => "0", 'text_end' => "0", 'description' => "")
    end
  end

  def process_closure(hash, geo_accession, field_name, ncbo_id)
    hash.keys.each do |key|
      hash[key].each do |closure|
        current_ncbo_id, term_id = closure[:id].split("|")
        key_current_ncbo_id, key_term_id = key.split("|")
        save_term('term_id' => "#{ncbo_id}|#{term_id}", 'ncbo_id' => ncbo_id, 'term_name' => closure[:name])
        save_closure('geo_accession' => geo_accession, 'field_name' => field_name, 'term_id' => "#{ncbo_id}|#{key_term_id}", 'closure_term' => "#{ncbo_id}|#{term_id}")
      end
    end
  end

  def save_term(params)
    databaser_message({'command' => 'saveterm'}.merge!(params))
  end

  def save_annotation(params)
    databaser_message({'command' => 'saveannotation'}.merge!(params))
  end

  def save_closure(params)
    databaser_message({'command' => 'saveclosure'}.merge!(params))
  end

  def databaser_message(msg)
    Crowd.submit('databaser', msg)
  end

end
