require 'xcodeproj'
project_path = 'BaoLianDeng.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BaoLianDeng' }

target.source_build_phase.files.each do |f|
  if f.file_ref && f.file_ref.path && f.file_ref.path.include?('Routing')
    if f.file_ref.path.include?('BaoLianDeng/Models/')
      f.file_ref.path = 'RoutingManager.swift'
    elsif f.file_ref.path.include?('BaoLianDeng/Views/')
      f.file_ref.path = 'RoutingRulesView.swift'
    end
  end
end
project.save
