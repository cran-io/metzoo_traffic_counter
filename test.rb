require 'rest-client'
require 'json'


r = RestClient.post('api.metzoo.com/register',{:customer_key => "a707c86a-51c0-4735-bf5f-68b68edb5f66",:host_name => 'P'}.to_json, :content_type=>:json)

# Agent Key: 603d718b-11ce-4ad0-b15e-0fbfc7be998f

response_object = JSON.parse(r)

agent_config = RestClient.get('http://api.metzoo.com/agent_config', {:content_type=>:json,:"Agent-Key"=>response_object["Agent-Key"]})

r = RestClient.post('http://api.metzoo.com/metric',[["Sarasa",Time.now.to_i,rand]].to_json, {:content_type=>:json,:"Agent-Key"=>"603d718b-11ce-4ad0-b15e-0fbfc7be998f"})

r = RestClient.post('http://api.metzoo.com/custom_metric',[{:id=>"Sarasa",:description=>"Un valor de algo",:submetrics=>["La posta"],:scale=>1,:y_title=>'sarasa',:polling_interval=>60,:enabled=>true,:read_only=>false},{:id=>"Temp",:description=>"Un valor de algo",:submetrics=>["La posta"],:scale=>1,:y_title=>'teeemp',:polling_interval=>60,:enabled=>true,:read_only=>false}].to_json, {:content_type=>:json,:"Agent-Key"=>response_object["Agent-Key"]})

