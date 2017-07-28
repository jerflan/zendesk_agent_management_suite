# The user passes a csv with agent email addresses and a column for each user field that needs to be updated.

require 'zendesk_api'
require 'csv'

filename = "./filename.csv"
custom_role_id = 1234567
password = "YoUr#1KrazyPa$$word"
new_default_group_id = 2345678
group2_id = 3456789



####################################################
############ ZENDESK API AUTHORIZATION #############
####################################################

client = ZendeskAPI::Client.new do |config|

  config.url = "https://[subdomain].zendesk.com/api/v2"
  config.username = ENV["ZD_USERNAME"]
  config.token = ENV["ZD_TOKEN"]
  # stored locally in .bash_profile

  config.retry = true
  require 'logger'
  config.logger = Logger.new(STDOUT)
end



####################################################
######### EXTRACT EMAILS AND GET USER IDS ##########
####################################################

def extract_user_emails(user_fields, client)
  user_emails = []
  user_fields.each_index do |row|
    user_emails.push(user_fields[row][0])
  end
  user_emails
end

def get_user_ids(client, user_emails)
  user_ids = []
  user_emails.each do |email|
    user_ids.push(client.users.search(query:"#{email}").map { |user| user.id})
    puts "\n"
    puts "-" * 40
    puts "#{email} found!"
    puts "-" * 40
    puts "\n"
  end
  user_ids.flatten
end



####################################################
########### ADD user_ids TO user_fields ############
####################################################

def combine(user_fields, user_ids)
  user_fields.each_index do |idx|
    user_fields[idx].push(user_ids[idx])
  end
end



####################################################
########## CHANGE TO A CUSTOM AGENT ROLE ###########
####################################################

def change_role(user_ids, custom_role_id, client)
  user_ids.each do |user_id|
    client.users.update!(id:user_id, custom_role_id:custom_role_id)
    puts "\n"
    puts "-" * 40
    puts "User: #{user_id}, Role #{custom_role_id}"
    puts "-" * 40
    puts "\n"
  end
end



####################################################
############ POPULATE USER FIELD VALUES ############
####################################################

# Please update the index numbers to reflect the number of user fields being passed

def add_user_fields(user_fields, client)
  user_fields.each_index do |uf_idx|
    client.users.update!(
      id:user_fields[uf_idx][5],
      time_zone:"Arizona",
      tags: ["tag1", "tag2"],
      user_fields:{
        # text fields or drop downs
        custom_field_1:"#{user_fields[uf_idx][1]}",
        custom_field_2:"#{user_fields[uf_idx][2]}",
        custom_field_3:"#{user_fields[uf_idx][3]}",
        # numeric
        custom_field_4:user_fields[uf_idx][4]
      }
    )
    puts "\n"
    puts "-" * 40
    puts "#{user_fields[uf_idx][0]} complete!"
    puts "-" * 40
    puts "\n"
  end
end



####################################################
################### SET PASSWORD ###################
####################################################

def set_password!(user_ids, password, client)
  user_ids.each do |user_id|
    client.users.find(id:user_id).set_password!(password: password)
    puts "\n"
    puts "-" * 40
    puts "Password set to #{password}"
    puts "-" * 40
    puts "\n"
  end
end



####################################################
####### CAPTURE INITIAL DEFAULT GROUP ########
####################################################


def get_default_group_membership_id(user_ids, client)
  default_gm_ids = []
  user_ids.each do |user_id|
    default_gm_ids.push(client.users.find(id:user_id).group_memberships.select do |group_membership|
      group_membership["default"]
    end.map { |gm| gm.id  })
  end
    default_gm_ids
end



####################################################
####### ADD GROUPS AND CHANGE DEFAULT GROUP ########
####################################################

def add_groups(user_ids, new_default_group_id, group2_id, client)
  user_ids.each do |user_id|
    client.group_memberships.create_many!([{user_id:user_id,  group_id:new_default_group_id, default:true},{user_id:user_id, group_id:group2_id}])
    puts "\n"
    puts "-" * 40
    puts "New Default Group: #{new_default_group_id}"
    puts "#{group2_id} also added to #{user_id}"
    puts "-" * 40
    puts "\n"
  end
end



####################################################
##### DESTROY FORMER DEFAULT GROUP MEMBERSHIPS #####
####################################################

def remove_original_group(default_gm_ids, client)
  default_gm_ids.each do |gm_id|
    client.group_memberships.destroy!(id:gm_id)
    puts "\n"
    puts "-" * 40
    puts "Removed (DO NOT SELECT)Default Group!"
    puts "-" * 40
    puts "\n"
  end
end



user_fields = CSV.read(filename)
user_fields.shift
user_emails = extract_user_emails(user_fields, client)
user_ids = get_user_ids(client, user_emails)
combine(user_fields, user_ids)
change_role(user_ids, custom_role_id, client)
default_gm_ids = get_default_group_membership_id(user_ids, client)
add_groups(user_ids, new_default_group_id, group2_id, client)
remove_original_group(default_gm_ids, client)
add_user_fields(user_fields, client)
set_password!(user_ids, password, client)
