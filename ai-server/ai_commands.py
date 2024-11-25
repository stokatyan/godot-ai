import json
from sac_torch import SAC_Agent as Agent
from utils import MeanStdevFilter, Transition, make_checkpoint, load_checkpoint, write_policy, write_to_file

COMMAND = "command"
GET_ACTION = "get_action"
GET_BATCH_ACTIONS = "get_batch_actions"
SUBMIT_BATCH_REPLAY = "submit_batch_replay"
TRAIN = "train"
INIT = "init"
LOAD = "load"
WRITE_POLICY = "write_policy"

agent = Agent(
    state_dim=6, 
    action_dim=2,
    batchsize=500,
    hidden_size=50
)

def respond_to_command(command_json):
    response = {}
    
    if command_json[COMMAND] == GET_ACTION:
        response = _get_action(command_json)
    elif command_json[COMMAND] == GET_BATCH_ACTIONS:
        response = _get_batch_actions(command_json)
    elif command_json[COMMAND] == SUBMIT_BATCH_REPLAY:
        response = _submit_batch_replay(command_json)
    elif command_json[COMMAND] == TRAIN:
        response = _train(command_json)
    elif command_json[COMMAND] == INIT:
        response = _init_agent(command_json)
    elif command_json[COMMAND] == LOAD:
        response = _load_agent(command_json)
    elif command_json[COMMAND] == WRITE_POLICY:
        response = _write_agent_policy_matrix(command_json)
    else:
        response = {}

    # Send the response as JSON
    json_response = json.dumps(response)
    return json_response

def _get_action(command_json):
    state = command_json["state"]
    
    action = agent.get_action(state, deterministic=True)

    response = {
        "action": action.tolist()
    }
    
    return response

def _get_batch_actions(command_json):
    deterministic = ["deterministic"]
    batch_state_path = command_json["path"]
    batch = []
    current_state = []
    batch_actions = []
    
    batch_state_json = {}
    try:
        with open(batch_state_path, 'r') as file:
            batch_state_json = json.load(file)  # Parse the JSON content
            batch = batch_state_json["batch_state"]
    except FileNotFoundError:
        print(f"[_submit_batch_replay] -> File not found: {batch_state_path}")
    except json.JSONDecodeError as e:
        print(f"[_submit_batch_replay] -> Error decoding JSON: {e}")
    
    for i in range(len(batch)):
        current_state.append(batch[i])
        if len(current_state) == agent.state_dim:
            action = agent.get_action(current_state, deterministic=deterministic)
            if agent.action_dim == 1:
                batch_actions.append(float(action))
            else:
                for a in action:
                    batch_actions.append(float(a))
            current_state = []
    
    
    actions_path = "AIServerCommFiles/batch_action.json"
    batch_actions_data = {}
    batch_actions_data["actions"] = batch_actions
    write_to_file(actions_path, batch_actions_data)
    response = {
        "path": actions_path
    }
    
    return response

def _submit_batch_replay(command_json):
    batch_replays_path = command_json["path"]
    
    batch_replay_json = {}
    try:
        with open(batch_replays_path, 'r') as file:
            batch_replay_json = json.load(file)  # Parse the JSON content
    except FileNotFoundError:
        print(f"[_submit_batch_replay] -> File not found: {batch_replays_path}")
    except json.JSONDecodeError as e:
        print(f"[_submit_batch_replay] -> Error decoding JSON: {e}")
    
    batch_replay = batch_replay_json["replays"]
    
    for replay in batch_replay:
        state = replay["state"]
        action = replay["action"]
        reward = replay["reward"]
        state_ = replay["state_"]
        done = replay["done"]
        agent.replay_pool.push(Transition(state, action, reward, state_, done))
    
    print(f"Received {len(batch_replay)} replays")
    
    response = {
        "done": True
    }

    return response

def _train(command_json):
    print_logs = command_json["print_logs"]
    steps = command_json["steps"]
    
    q1_loss, q2_loss, pi_loss, a_loss = agent.optimize(steps)
    
    _write_agent_policy_matrix(command_json)
    if "checkpoint" in command_json:
        checkpoint = command_json["checkpoint"]
        make_checkpoint(agent, checkpoint)
    
    if print_logs:
        print("----- Training Report -----")
        print(f'q1_loss : {q1_loss/float(steps)}')
        print(f'q2_loss : {q2_loss/float(steps)}')
        print(f'pi_loss : {pi_loss/float(steps)}')
        print(f'a_loss  : {a_loss/float(steps)}')
        print("---------------------------")
    
    response = {
        "done": True
    }

    return response

def _init_agent(command_json):
    global agent 
    try:
        agent = Agent(
            state_dim=command_json["state_dim"], 
            action_dim=command_json["action_dim"],
            batchsize=command_json["batchsize"],
            hidden_size=command_json["hidden_size"],
            num_actor_layers=command_json["num_actor_layers"],
            num_critic_layers=command_json["num_critic_layers"]
        )
        print("New Agent initialized")
    except Exception as e:
        print(f"Failed to initialize agent: {e}")

    response = {
        "done": True
    }

    return response

def _load_agent(command_json):
    did_load = load_checkpoint(agent, command_json["step_count"])
    
    if not did_load:
        _write_agent_policy_matrix(command_json)
    
    response = {
        "done": True
    }
    
    print("Agent loaded")

    return response

def _write_agent_policy_matrix(command_json):
    write_policy(agent.policy)
    
    response = {
        "done": True
    }
    
    print("Agent's policy written to policy.json file")

    return response