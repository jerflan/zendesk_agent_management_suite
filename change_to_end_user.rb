# Use this file to either
  # 1. Revert changes made in the bulk creation program if an error occurs.
  # 2. Move a large group deactivated agents to end_user. 
  # 3. Optional suspend_user method included.
# The user passes a csv with agent email addresses and a column for each user field that needs to be updated.

require 'zendesk_api'
require 'csv'

subdomain = "your_companys_zendesk_subdomain"
filename = "./filename.csv"



####################################################
############ ZENDESK API AUTHORIZATION #############
####################################################

client = ZendeskAPI::Client.new do |config|

  config.url = "https://#{subdomain}.zendesk.com/api/v2"
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

def find_or_create_users(client, user_emails)
  user_emails.each do |email|
    user_query = client.users.search(query:"#{email}")
    if (user_query.count == 0)
      client.users.create!(name:"#{email}", email:"#{email}")
      puts "\n"
      puts "-" * 40
      puts "New user created for #{email}"
      puts "-" * 40
      puts "\n"
    else
      puts "\n"
      puts "-" * 40
      puts "Existing user found for #{email}"
      puts "-" * 40
      puts "\n"
    end
  end
end

def get_user_ids(client, user_emails)
  user_ids = []
  user_emails.each do |email|
    user_query = client.users.search(query:"#{email}")
    user_ids.push(user_query.map { |user| user.id})
    puts "\n"
    puts "-" * 40
    puts "user_id for #{email} found!"
    puts "-" * 40
    puts "\n"
  end
  user_ids.flatten
end

####################################################
############### CHANGE TO END USER #################
####################################################

# def find_suspended_agents(client, user_ids)
#   user_ids.push(client.users.search(query:{suspended:true}).map { |user| user.id})
#       puts "\n"
#     puts "-" * 40
#     puts "#{user.id} found!"
#     puts "-" * 40
#     puts "\n"
# end

def change_role_to_end_user(client, user_ids)
  user_ids.each do |uid|
    client.users.update!(
      id:uid,
      role:"end-user",
      # optional removal of user field values
      user_fields:{
        customer_user_field_1:"",
        customer_user_field_2:""
        }
    )
    puts"\n"
    puts "-" * 40
    puts "#{uid} changed to End User and user fields cleared."
    puts "-" * 40
    puts"\n"
  end
end

def suspend_user(client, user_ids)
  user_ids.each do |uid|
    client.users.update!(id:uid, suspended:true)
    puts"\n"
    puts "-" * 40
    puts "#{uid} suspended!"
    puts "-" * 40
    puts"\n"
  end
end


user_fields = CSV.read(filename)
user_fields.shift
user_emails = extract_user_emails(user_fields, client)
find_or_create_users(client, user_emails)
user_ids = get_user_ids(client, user_emails)
change_role_to_end_user(client, user_ids)
# comment out the line below if you don't want to suspend users in the csv
suspend_user(client, user_ids)