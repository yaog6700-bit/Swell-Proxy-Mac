require 'xcodeproj'
project_path = 'BaoLianDeng.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BaoLianDeng' }

# Remove duplicate build files in sources build phase based on file name
seen_names = {}
target.source_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    name = build_file.file_ref.name || build_file.file_ref.path
    if name && (name.include?('RoutingManager.swift') || name.include?('RoutingRulesView.swift'))
      if seen_names[name]
        build_file.remove_from_project
      else
        seen_names[name] = true
      end
    end
  end
end

project.save
