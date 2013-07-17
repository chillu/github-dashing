require 'json'
require 'time'
require 'dashing'
require 'net/https'
require 'cgi'
require File.expand_path('../../lib/travis_backend', __FILE__)

SCHEDULER.every '1h', :first_in => '1s' do |job|
	backend = TravisBackend.new
	repo_slugs = []
	builds = []
	branch_whitelist = /^(\d+\.\d+|master)/

	if ENV['ORGAS']
		ENV['ORGAS'].split(',').each do |orga|
			repo_slugs = repo_slugs.concat(backend.get_repos_by_orga(orga).collect{|repo|repo['slug']})
		end
	end
	
	if ENV['REPOS']
		repo_slugs.concat(ENV['REPOS'].split(','))
	end

	repo_slugs.sort!

	items = repo_slugs.map do |repo_slug|
		repo_builds = backend.get_builds_by_repo(repo_slug)
		if repo_builds and repo_builds.length > 0
			puts repo_slug
			# Get the newest build for each branch
			branches = repo_builds
				.group_by {|build|build['branch']}
				.select {|branch,builds_for_branch|branch_whitelist.match(branch) }
				.map do |branch,builds_for_branch|
					{
						'class'=>(builds_for_branch[0]['result'] == 0) ? 'good' : 'bad', # POSIX return code
						'label'=>builds_for_branch[0]['branch'],
						'title'=>builds_for_branch[0]['finished_at'],
						'result'=>builds_for_branch[0]['result'],
						'url'=> 'https://travis-ci.org/%s/builds/%d' % [repo_slug,builds_for_branch[0]['id']]
					} 
				end
			{
				'label'=>repo_slug,
				'class'=> (branches.reject{|b|b['result'] != nil and b['result'] == 0}.count > 0) ? 'bad' : 'good', # POSIX return code
				'url' => branches.count ? 'https://travis-ci.org/%s' % repo_slug : '',
				'items' => branches
			}
		else
			{
				'label'=>repo_slug,
				'class'=> 'none',
				'url' => '',
				'items' => []
			}
		end
	end
	
	send_event('travis', {
		unordered: true,
		items: items
	})
end