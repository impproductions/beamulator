defmodule Beamulator.Tools.Actor do
  def get_action_count(actor_data) do
    # TODO: is this a bad practice? copying all the data always...?
    actor_data.actor_runtime.action_count
  end
end
