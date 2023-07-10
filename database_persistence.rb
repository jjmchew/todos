require 'pg'

class DatabasePersistence
  def initialize(mode, logger)
    if mode == 'DEV'
      @db = PG.connect(dbname: 'jjmchewa_todos')
    else
      @db = PG.connect(dbname: 'jjmchewa_todos', user: 'jjmchewa_pg', password: 'db123')
    end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    #@session[:lists].find{ |list| list[:id] == id }
     sql = <<~SQL
      SELECT lists.*,
             COUNT(todos.id) AS todos_count,
             COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      WHERE lists.id = $1
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL
    result = query(sql, list_id) 

    tuple_to_list_hash(result.first)
 end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
             COUNT(todos.id) AS todos_count,
             COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL
    result = query(sql)

    result.map { |tuple| tuple_to_list_hash(tuple) }
  end

  def create_new_list(list_name)
    sql = 'INSERT INTO lists (name) VALUES ($1)'
    query(sql, list_name)
  end

  def delete_list(id)
    query('DELETE FROM todos WHERE list_id = $1', id)
    query('DELETE FROM lists WHERE id = $1', id)
  end

  def update_list_name(id, new_name)
    sql = 'UPDATE lists SET name = $1 WHERE id = $2'
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = 'INSERT INTO todos (name, list_id) VALUES ($1, $2);'
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = 'DELETE FROM todos WHERE id = $1 AND list_id = $2'
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = 'UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3'
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    query("UPDATE todos SET completed = 't' WHERE list_id = $1", list_id)
  end

  def load_todos(list_id)
    sql2 = 'SELECT * FROM todos WHERE list_id = $1'
    result2 = query(sql2, list_id)

    result2.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { id: tuple['id'].to_i,
      name: tuple['name'],
      todos_count: tuple['todos_count'].to_i,
      todos_remaining_count: tuple['todos_remaining_count'].to_i,
    }
  end
end
