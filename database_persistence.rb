require "pg"


DATABASE_NAME = 'todo_app_db'
LISTS_TABLE = 'lists'
TODOS_TABLE = 'todos'
SCHEMA_FILE = 'schema.sql'

class DatabasePersistence

    def initialize(logger)
      @db = PG.connect(dbname: DATABASE_NAME)
      @logger = logger
      @lists = @db.quote_ident(LISTS_TABLE)
      @todos = @db.quote_ident(TODOS_TABLE)
      setup_schema
    end

    def create_tables
      create_tables = File.open(SCHEMA_FILE) { |file| file.read }
      @db.exec(create_tables)
    end

    def table_exists?(table_name)
      query_table_existence = <<~SQL
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = $1; 
      SQL

      result = query(query_table_existence, table_name)
      result.field_values('count')[0].to_i == 1 ? true : false
    end

    def setup_schema
      create_tables unless table_exists?(LISTS_TABLE) &&
                           table_exists?(TODOS_TABLE)
    end

    def query(statement, *params) 
      log_SQL(statement, params)
      @db.exec_params(statement, params)
    end

    def log_SQL(statement, params)
      log_string = <<~LOG
      \n
      SQL Query
      ---------------------
      #{statement}
      LOG
      params.each_with_index do |param, index|
        log_string += "\n$#{index + 1}: #{param}\n"
      end
      log_string += "---------------------"
      @logger.info(log_string)
    end
  
    def find_list(id)
      search = <<~SQL
      SELECT * FROM #{@lists}
      WHERE id = $1
      SQL

      result = query(search, id)
      format_list(result.first)
    end

    def todos_from_list_id(list_id)
      todos = <<~SQL
      SELECT * FROM #{@todos}
      WHERE list_id = $1;
      SQL

      result = query(todos, list_id)
      format_todos(result)
    end

    def format_todos(data)
      todos = []
      data.each do |tuple|
        todo_id = tuple["id"]
        todo_name = tuple["name"]
        completed = tuple["completed"] == "t" ? true : false
        todos << { id: todo_id, name: todo_name, completed: completed }
      end
      todos
    end

    def format_list(tuple)
      list_id = tuple["id"]
      name = tuple["name"]
      todos = todos_from_list_id(list_id) || []
      {id: list_id, name: name, todos: todos}
    end

    def format_list_of_lists(data)
      data.map do |tuple|
        format_list(tuple)
      end
    end
  
    def all_lists
      select_lists = <<~SQL
      SELECT * FROM #{@lists};
      SQL

      result = query(select_lists)
      format_list_of_lists(result)
    end
    
    def create_new_list(list_name)
      add_list = <<~SQL
      INSERT INTO #{@lists} (name)
      VALUES ($1);
      SQL

      query(add_list, list_name)
    end
  
    def create_new_todo(list_id, todo_name)
      add_todo = <<~SQL
      INSERT INTO #{@todos} (name, list_id)
      VALUES ($1, $2);
      SQL

      query(add_todo, todo_name, list_id)
    end
  
    def delete_list(id)
      delete_list = <<~SQL
      DELETE FROM #{@lists}
      WHERE id = $1;
      SQL

      query(delete_list, id)
    end
  
    def update_list_name(id, new_name)
      rename = <<~SQL
      UPDATE #{@lists}
      SET name = $1 WHERE id = $2
      SQL

      query(rename, new_name, id)
    end
  
    def delete_todo_from_list(list_id, todo_id)
      delete_todo = <<~SQL
      DELETE FROM #{@todos}
      WHERE id = $1 AND list_id = $2;
      SQL

      query(delete_todo, todo_id, list_id)
    end
  
    def update_todo_status(list_id, todo_id, new_status)
      update = <<~SQL
      UPDATE #{@todos}
      SET completed = $3
      WHERE id = $1 AND list_id = $2;
      SQL

      query(update, todo_id, list_id, new_status)
    end
  
    def mark_all_todos_as_completed(list_id)
      complete_all = <<~SQL
      UPDATE #{@todos}
      SET completed = true
      WHERE list_id = $1
      SQL

      query(complete_all, list_id)
    end
  end
  