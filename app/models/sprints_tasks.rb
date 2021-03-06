class SprintsTasks < Issue
  unloadable

  acts_as_list :column => "ir_position"

  ORDER = 'case when issues.ir_position is null then 1 else 0 end ASC, case when issues.ir_position is NULL then issues.id else issues.ir_position end ASC'

  def self.get_tasks_by_status(project, status, sprint, user)
    projects = []
    tasks = []
    Project.find(:all, :select => 'id', :conditions => ["id = ? or parent_id = ?", project.id, project.id]).each{|proj| projects << proj.id}
    cond = ["issues.project_id in (?) and status_id = ?", projects, status]
    unless sprint.nil?
      if sprint == 'null'
        cond[0] += ' and fixed_version_id is null'
      else
        cond[0] += ' and fixed_version_id = ?'
        cond << sprint
      end
    end
    unless user.nil?
      cond[0] += ' and assigned_to_id = ?'
      user = User.current.id if user == 'current'
      cond << user
    end
    SprintsTasks.find(:all, :select => 'issues.*, sum(hours) as spent', :order => SprintsTasks::ORDER, :conditions => cond, :group => "issues.id",
                      :joins => [:status], :joins => "left join time_entries ON time_entries.issue_id = issues.id", :include => [:assigned_to]).each{|task| tasks << task}
    return tasks
  end

  def self.get_tasks_by_sprint(project, sprint)
    projects = []
    tasks = []
    Project.find(:all, :select => 'id', :conditions => ["id = ? or parent_id = ?", project.id, project.id]).each{|proj| projects << proj.id}
    cond = ["project_id in (?) and is_closed = ?", projects, false]
    unless sprint.nil?
      if sprint == 'null'
        cond[0] += ' and fixed_version_id is null'
      else
        cond[0] += ' and fixed_version_id = ?'
        cond << sprint
      end
    end
    SprintsTasks.find(:all, :order => SprintsTasks::ORDER, :conditions => cond, :joins => :status, :include => :assigned_to).each{|task| tasks << task}
    return tasks
  end

  def self.get_backlog(project)
    return SprintsTasks.get_tasks_by_sprint(project, 'null')
  end

  def move_after(prev_id)
    remove_from_list

    if prev_id.to_s == ''
      prev = nil
    else
      prev = SprintsTasks.find(prev_id)
    end

    if prev.blank?
      insert_at
      move_to_top
    elsif !prev.in_list?
      insert_at
      move_to_bottom
    else
      insert_at(prev.ir_position + 1)
    end
  end

  def update_and_position!(params)
    attribs = params.select{|k,v| k != 'id' && k != 'project_id' && SprintsTasks.column_names.include?(k) }
    attribs = Hash[*attribs.flatten]
    if params[:prev]
      move_after(params[:prev])
    end
    self.init_journal(User.current)
    update_attributes attribs
  end
end