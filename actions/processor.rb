require File.dirname(__FILE__) + '/support/setup'

class Processor < CloudCrowd::Action

  def process
    process_task(input)
  end

  def process_task(params)
    send_scheduler({'command' => 'working', 'task_id' => params['task_id'], 'time' => Time.now.to_f})
    # params = {'task_id' => task.id, 'geo_accession' => task.geo_accession, 'field' => task.field, 'value' => item.send(task.field), 'description' => item.descriptive_text, 'ncbo_id' => ncbo_id, 'stopwords' => stopwords}
    create_for(params['geo_accession'], params['field'], params['value'], params['description'], params['ncbo_id'], params['stopwords'], params['email'])
    send_scheduler({'command' => 'finished', 'task_id' => params['task_id'], 'time' => Time.now.to_f})
    rescue NCBOException => ex
      send_scheduler({'command' => 'failed', 'task_id' => params['task_id'], 'exception' => ex.message})
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
        send_databaser('command' => 'saveterm', 'term_id' => "#{ncbo_id}|#{term_id}", 'ncbo_id' => ncbo_id, 'term_name' => hash[key][:name])
        send_databaser('command' => 'saveannotation', 'geo_accession' => geo_accession, 'field_name' => field_name, 'ncbo_id' => ncbo_id, 'ontology_term_id' => "#{ncbo_id}|#{term_id}", 'text_start' => hash[key][:from], 'text_end' => hash[key][:to], 'description' => description)
      end
    end
  end

  def process_closure(hash, geo_accession, field_name, ncbo_id)
    hash.keys.each do |key|
      hash[key].each do |closure|
        current_ncbo_id, term_id = closure[:id].split("|")
        key_current_ncbo_id, key_term_id = key.split("|")
        send_databaser('command' => 'saveterm', 'term_id' => "#{ncbo_id}|#{term_id}", 'ncbo_id' => ncbo_id, 'term_name' => closure[:name])
        send_databaser('command' => 'saveclosure', 'geo_accession' => geo_accession, 'field_name' => field_name, 'term_id' => "#{ncbo_id}|#{key_term_id}", 'closure_term' => "#{ncbo_id}|#{term_id}")
      end
    end
  end

  def send_databaser(msg)
    Crowd.submit('databaser', msg)
  end

  def send_scheduler(msg)
    Crowd.submit('scheduler', msg)
  end

end
