import ArgumentParser
import RunnerLib

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: "Declarative task scheduler for macOS",
        version: "0.1.0",
        subcommands: [Auto.self, Run.self, List.self, Validate.self, MonitorCommand.self, Init.self, Logs.self, Api.self, Cleanup.self, Complete.self, Migrate.self, TaskSave.self]
    )
}
