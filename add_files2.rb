require 'xcodeproj'
project_path = 'BaoLianDeng.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BaoLianDeng' }

models_group = project.main_group.find_subpath(File.join('BaoLianDeng', 'Models'), false)
if models_group.nil?
    models_group = project.main_group.find_subpath('BaoLianDeng', false).new_group('Models')
end
file_ref1 = models_group.new_reference('RoutingManager.swift')
target.add_file_references([file_ref1])

views_group = project.main_group.find_subpath(File.join('BaoLianDeng', 'Views'), false)
file_ref2 = views_group.new_reference('RoutingRulesView.swift')
target.add_file_references([file_ref2])

project.save
