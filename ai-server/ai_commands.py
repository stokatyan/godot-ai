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

agents = {}

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
    agent_name = command_json["file_name"]
    agent = agents[agent_name]
    
    action = agent.get_action(state, deterministic=True)

    response = {
        "action": action.tolist()
    }
    
    return response

def _get_batch_actions(command_json):
    deterministic_map = command_json["deterministic_map"]
    batch_state_path = command_json["path"]
    current_state = []
    
    batch_state_json = {}
    try:
        with open(batch_state_path, 'r') as file:
            batch_state_json = json.load(file)  # Parse the JSON content
    except FileNotFoundError:
        print(f"[_submit_batch_replay] -> File not found: {batch_state_path}")
    except json.JSONDecodeError as e:
        print(f"[_submit_batch_replay] -> Error decoding JSON: {e}")
    
    batch_actions_data = {}
    for name in batch_state_json:
        batch_actions = []
        batch = batch_state_json[name]
        agent = agents[name]
        deterministic = name in deterministic_map and deterministic_map[name] == True
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
        batch_actions_data[name] = batch_actions
    
        if len(current_state) != 0:
            print()
            print(f"Unexpected leftover state values for: {name}")
            print()

    actions_path = "AIServerCommFiles/batch_action.json"
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
    replay_counts = {}
    
    for replay in batch_replay:
        state = replay["state"]
        action = replay["action"]
        reward = replay["reward"]
        state_ = replay["state_"]
        done = replay["done"]
        agent_name = replay["agent_name"]
        agent = agents[agent_name]
        transition = Transition(state, action, reward, state_, done)
        print(transition)
        agent.replay_pool.push(transition)
        if agent_name in replay_counts:
            replay_counts[agent_name] += 1
        else:
            replay_counts[agent_name] = 1
        
    for name in replay_counts:
        print(f"Received {replay_counts[name]} replays for {name}")
    
    response = {
        "done": True
    }

    return response

def _train(command_json):
    print_logs = command_json["print_logs"]
    steps = command_json["steps"]
    file_name = command_json["file_name"]
    agent = agents[file_name]
        
    q1_loss, q2_loss, pi_loss, a_loss = agent.optimize(steps)
    _write_agent_policy_matrix(command_json)
    make_checkpoint(agent, file_name)
    
    if print_logs:
        print("----- Training Report -----")
        print(file_name)
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
    try:
        agent_name = command_json["file_name"]
        agent = Agent(
            state_dim=command_json["state_dim"], 
            action_dim=command_json["action_dim"],
            batchsize=command_json["batchsize"],
            hidden_size=command_json["hidden_size"],
            num_actor_layers=command_json["num_actor_layers"],
            num_critic_layers=command_json["num_critic_layers"],
            replay_capacity=command_json["replay_capacity"]
        )
        agents[agent_name] = agent
        print(f"Agent named {agent_name} initialized.")
    except Exception as e:
        print(f"Failed to initialize {agent_name}: {e}")

    response = {
        "done": True
    }

    return response

def _load_agent(command_json):
    agent_name = command_json["file_name"]
    agent = agents[agent_name]
    if agent is not None:
        load_checkpoint(agent, agent_name)
    
    response = {
        "done": True
    }

    return response

def _write_agent_policy_matrix(command_json):
    file_name = command_json["file_name"]
    write_policy(agents[file_name].policy, file_name)
    response = {
        "done": True
    }

    return response