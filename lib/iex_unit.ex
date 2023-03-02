defmodule IExUnit do
  @moduledoc """
  Copied some code from here: https://github.com/Olshansk/test_iex/blob/9bafb3bc4e89555ab7ad87b9593b1bfc6b71caaa/lib/test_iex.ex, 
  but added more features to support VScode and Neovim.

  Copyright (c) 2019 - 2021 Daniel Olshansky
  Copyright (c) 2023 Scott Ming

  A utility module that helps you iterate faster on unit tests.
  This module lets execute specific tests from within a running iex shell to
  avoid needing to start and stop the whole application every time.
  """

  @doc """
  Starts the testing context.
  ## Examples
      iex> IExUnit.start()
  """
  def start() do
    ExUnit.start()
    Code.compiler_options(ignore_module_conflict: true)

    if File.exists?("test/test_helper.exs") do
      Code.eval_file("test/test_helper.exs", File.cwd!())
    end

    :ok
  end

  @doc """
  Loads or reloads testing helpers
  ## Examples
      iex> IExUnit.load_helper(“test/test_helper.exs”)
  """
  def load_helper(file_name) do
    Code.eval_file(file_name, File.cwd!())
  end

  @doc """
  Runs a single test, a test file, or multiple test files
  ## Example: Run a single test
      iex> IExUnit.run("./path/test/file/test_file_test.exs", line: line_number)
  ## Example: Run a single test file
      iex> IExUnit.run("./path/test/file/test_file_test.exs")
  ## Example: Run a single test file with a specific seed
      iex> IExUnit.run("./path/test/file/test_file_test.exs", seed: seed_number)
  ## Example: Run several test files:
      iex> IExUnit.run(["./path/test/file/test_file_test.exs", "./path/test/file/test_file_2_test.exs"])
  ## Example: Run all tests in a directory:
      iex> IExUnit.run("test")
  """
  def run(path, options \\ [])

  def run(path, options) do
    paths =
      path
      |> List.wrap()
      |> Enum.map(fn p -> if File.dir?(p), do: ls(p), else: p end)
      |> List.flatten()

    run_test(paths, options)
  end

  defp ls(dir) do
    abs_dir = Path.expand(".", dir)
    Path.wildcard("#{abs_dir}/**/*_test.exs")
  end

  defp run_test(files, options) do
    IEx.Helpers.recompile()

    with {:ok, _, _} <- Kernel.ParallelCompiler.compile(files) do
      configure(options)
      server_modules_loaded()
      ExUnit.run()
    end
  end

  defp configure(options) do
    options = opts_for_line(options) ++ opts_for_seed(options)
    ExUnit.configure(options)
  end

  defp opts_for_line(options) do
    line = Keyword.get(options, :line)

    if line do
      [exclude: [:test], include: [line: line]]
    else
      [exclude: [], include: []]
    end
  end

  defp opts_for_seed(options) do
    seed = Keyword.get(options, :seed)
    if seed, do: [seed: seed], else: []
  end

  if System.version() > "1.14.1" do
    defp server_modules_loaded(), do: ExUnit.Server.modules_loaded(false)
  else
    defp server_modules_loaded(), do: ExUnit.Server.modules_loaded()
  end
end