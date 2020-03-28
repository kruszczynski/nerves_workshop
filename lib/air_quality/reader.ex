defmodule AirQuality.Reader do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def init(_arg) do
    {:ok, uart_pid} = Circuits.UART.start_link()
    IO.puts(inspect(uart_pid))
    Circuits.UART.open(uart_pid, "ttyAMA0", framing: CircuitsUARTFramingPMS7003, active: false)
    Process.send_after(self(), :read, 1_000)
    {:ok, {uart_pid, <<>>}}
  end

  def handle_call(:get, _from, state = {_pid, payload}) do
    {:reply, payload, state}
  end

  def handle_info(:read, state = {uart_pid, payload}) do
    {:ok, data} = Circuits.UART.read(uart_pid, 10000)
    Logger.info(inspect(data))
    # new_payload = payload ++ data
    # send(self(), :process_data)
    Process.send_after(self(), :read, 5_000)
    {:no_reply, {uart_pid, payload}}
  end

  def handle_info(:process_data, state = {uart_pid, payload}) do
    case payload do
      {:ok,
       <<66, 77, _padding::binary-size(8), pm1::binary-size(2), pm25::binary-size(2),
         pm10::binary-size(2), _rest::binary>>} ->
        Logger.info(inspect(%{pm1: pm1, pm25: pm25, pm10: pm10}))
        {:noreply, {uart_pid, <<>>}}

      _ ->
        {:noreply, {uart_pid, payload}}
    end
  end
end
