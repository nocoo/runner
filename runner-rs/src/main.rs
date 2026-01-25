use std::path::PathBuf;
use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use chrono::{Utc, Datelike, Timelike, FixedOffset};

use runner_lib::{
    Scheduler,
    config::ConfigLoader,
    storage::Storage,
    executor::TaskExecutor,
    monitor::ProcessMonitor,
};

#[derive(Parser)]
#[command(name = "runner")]
#[command(about = "Declarative task scheduler for macOS")]
#[command(version)]
struct Cli {
    /// Data directory
    #[arg(short, long, default_value = "./data")]
    data_dir: PathBuf,
    
    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
    
    /// Dry run (don't execute tasks)
    #[arg(long)]
    dry_run: bool,
    
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run scheduled tasks based on current time
    Auto {
        /// Mock hour (for testing)
        #[arg(long)]
        mock_hour: Option<u32>,
        
        /// Mock minute (for testing)
        #[arg(long)]
        mock_minute: Option<u32>,
        
        /// Mock weekday (0=Sun, 6=Sat)
        #[arg(long)]
        mock_weekday: Option<u32>,
    },
    
    /// Run a specific task
    Run {
        /// Task ID
        task: String,
        
        /// Trigger type
        #[arg(short, long, default_value = "manual")]
        trigger: String,
    },
    
    /// List tasks
    List,
    
    /// Validate configuration
    Validate,
    
    /// Check running tasks and mark interrupted ones
    Monitor,
    
    /// Initialize data directory
    Init,
    
    /// Show logs for a task run
    Logs {
        /// Run ID (optional, shows latest if not specified)
        id: Option<String>,
        
        /// List all runs
        #[arg(short, long)]
        list: bool,
        
        /// Show last N lines
        #[arg(short, long)]
        tail: Option<usize>,
        
        /// Follow output (not yet implemented)
        #[arg(short, long)]
        follow: bool,
    },
    
    /// API queries (for compatibility)
    Api {
        /// Query type: tasks, schedules, runs, status, init
        query: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Initialize storage
    let storage = Storage::new(&cli.data_dir);
    
    match cli.command {
        Commands::Init => {
            storage.init()?;
            println!("Initialized data directory: {}", cli.data_dir.display());
        }
        
        Commands::Auto { mock_hour, mock_minute, mock_weekday } => {
            run_auto(&cli, &storage, mock_hour, mock_minute, mock_weekday)?;
        }
        
        Commands::Run { ref task, ref trigger } => {
            run_task(&cli, &storage, task, trigger)?;
        }
        
        Commands::List => {
            list_tasks(&cli)?;
        }
        
        Commands::Validate => {
            validate_config(&cli)?;
        }
        
        Commands::Monitor => {
            run_monitor(&cli, &storage)?;
        }
        
        Commands::Logs { ref id, list, tail, follow: _ } => {
            show_logs(&cli, id.clone(), list, tail)?;
        }
        
        Commands::Api { ref query } => {
            run_api(&cli, &storage, query)?;
        }
    }
    
    Ok(())
}

fn log_debug(verbose: bool, msg: &str) {
    if verbose {
        eprintln!("[DEBUG] {}", msg);
    }
}

fn run_auto(
    cli: &Cli,
    _storage: &Storage,
    mock_hour: Option<u32>,
    mock_minute: Option<u32>,
    mock_weekday: Option<u32>,
) -> Result<()> {
    // First run monitor to check stale tasks
    log_debug(cli.verbose, "Running monitor to check stale tasks");
    let monitor = ProcessMonitor::new(Storage::new(&cli.data_dir), cli.verbose);
    let interrupted = monitor.check_running_tasks()?;
    if !interrupted.is_empty() && cli.verbose {
        eprintln!("[DEBUG] Marked {} tasks as interrupted", interrupted.len());
    }
    
    // Load config
    let config = ConfigLoader::load_config(&cli.data_dir)
        .context("Failed to load config")?;
    
    // Get current time (or mock time)
    let now = Utc::now().with_timezone(&FixedOffset::east_opt(8 * 3600).unwrap()); // UTC+8
    let hour = mock_hour.unwrap_or(now.hour());
    let minute = mock_minute.unwrap_or(now.minute());
    let weekday = mock_weekday.unwrap_or(now.weekday().num_days_from_sunday());
    
    log_debug(cli.verbose, &format!(
        "Current time: hour={}, minute={}, weekday={}",
        hour, minute, weekday
    ));
    
    // Find scheduled tasks
    let tasks = Scheduler::find_scheduled_tasks(
        &config.schedules,
        &config.tasks,
        hour,
        minute,
        weekday,
    );
    
    if tasks.is_empty() {
        log_debug(cli.verbose, "No tasks scheduled for current time");
        return Ok(());
    }
    
    log_debug(cli.verbose, &format!("Found {} task(s) to execute", tasks.len()));
    
    // Execute tasks
    let executor = TaskExecutor::new(Storage::new(&cli.data_dir), cli.dry_run, cli.verbose);
    
    for task_id in tasks {
        if let Some(task) = ConfigLoader::get_task(&config.tasks, task_id) {
            log_debug(cli.verbose, &format!("Executing task: {}", task_id));
            
            match executor.execute(task, "scheduled") {
                Ok(result) => {
                    if cli.verbose {
                        eprintln!("[DEBUG] Task {} completed with exit code {}", task_id, result.exit_code);
                    }
                }
                Err(e) => {
                    eprintln!("Error executing task {}: {}", task_id, e);
                }
            }
        }
    }
    
    Ok(())
}

fn run_task(cli: &Cli, _storage: &Storage, task_id: &str, trigger: &str) -> Result<()> {
    let config = ConfigLoader::load_config(&cli.data_dir)?;
    
    let task = ConfigLoader::get_task(&config.tasks, task_id)
        .context(format!("Task not found: {}", task_id))?;
    
    log_debug(cli.verbose, &format!("Executing task: {}", task_id));
    
    let executor = TaskExecutor::new(Storage::new(&cli.data_dir), cli.dry_run, cli.verbose);
    let result = executor.execute(task, trigger)?;
    
    if !cli.verbose {
        println!("{}", result.output);
    }
    
    std::process::exit(result.exit_code);
}

fn list_tasks(cli: &Cli) -> Result<()> {
    let tasks = ConfigLoader::load_tasks(&cli.data_dir)?;
    
    for task in tasks {
        println!("{}: {} ({:?})", task.id, task.description, task.task_type);
    }
    
    Ok(())
}

fn validate_config(cli: &Cli) -> Result<()> {
    let config = ConfigLoader::load_config(&cli.data_dir)?;
    
    use runner_lib::config::ConfigValidator;
    ConfigValidator::validate_config(&config)?;
    
    println!("Configuration is valid");
    println!("  Tasks: {}", config.tasks.len());
    println!("  Schedules: {}", config.schedules.len());
    
    Ok(())
}

fn run_monitor(cli: &Cli, _storage: &Storage) -> Result<()> {
    let monitor = ProcessMonitor::new(Storage::new(&cli.data_dir), cli.verbose);
    let interrupted = monitor.check_running_tasks()?;
    
    if interrupted.is_empty() {
        println!("No interrupted tasks found");
    } else {
        println!("Marked {} tasks as interrupted:", interrupted.len());
        for id in interrupted {
            println!("  {}", id);
        }
    }
    
    Ok(())
}

fn show_logs(cli: &Cli, id: Option<String>, list: bool, tail: Option<usize>) -> Result<()> {
    let index = ConfigLoader::load_runs_index(&cli.data_dir)?;
    
    if list {
        for run in index.runs.iter().rev().take(20) {
            let status = match run.exit_code {
                Some(0) => "✓",
                Some(_) => "✗",
                None => "⋯",
            };
            println!("{} {} {} {}", status, run.id, run.task, run.started_at);
        }
        return Ok(());
    }
    
    let run_id = if let Some(id) = id {
        id
    } else {
        // Get latest run
        index.runs.last()
            .map(|r| r.id.clone())
            .context("No runs found")?
    };
    
    // Read output file
    let output_path = cli.data_dir.join(format!("runs/{}.output", run_id));
    let content = std::fs::read_to_string(&output_path)
        .context(format!("Output file not found: {}", output_path.display()))?;
    
    if let Some(n) = tail {
        let lines: Vec<&str> = content.lines().collect();
        let start = if lines.len() > n { lines.len() - n } else { 0 };
        for line in &lines[start..] {
            println!("{}", line);
        }
    } else {
        print!("{}", content);
    }
    
    Ok(())
}

fn run_api(cli: &Cli, storage: &Storage, query: &str) -> Result<()> {
    match query {
        "tasks" => {
            let tasks = ConfigLoader::load_tasks(&cli.data_dir)?;
            println!("{}", serde_json::to_string_pretty(&tasks)?);
        }
        "schedules" => {
            let schedules = ConfigLoader::load_schedules(&cli.data_dir)?;
            println!("{}", serde_json::to_string_pretty(&schedules)?);
        }
        "runs" => {
            let index = ConfigLoader::load_runs_index(&cli.data_dir)?;
            println!("{}", serde_json::to_string_pretty(&index)?);
        }
        "status" | "state" => {
            let state = ConfigLoader::load_state(&cli.data_dir)?;
            println!("{}", serde_json::to_string_pretty(&state)?);
        }
        "init" => {
            storage.init()?;
            println!("{{\"status\": \"ok\"}}");
        }
        _ => {
            eprintln!("Unknown API query: {}", query);
            std::process::exit(1);
        }
    }
    
    Ok(())
}
