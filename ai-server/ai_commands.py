import json
from sac_torch import SAC_Agent as Agent
from utils import MeanStdevFilter, Transition, make_checkpoint, load_checkpoint

COMMAND = "command"
GET_ACTION = "get_action"
GET_BATCH_ACTIONS = "get_batch_actions"
SUBMIT_BATCH_REPLAY = "submit_batch_replay"
TRAIN = "train"
INIT = "init"
LOAD = "load"

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
    batch = command_json["batch_state"]
    current_state = []
    batch_actions = []

    for i in range(len(batch)):
        current_state.append(batch[i])
        if len(current_state) == agent.state_dim:
            action = agent.get_action(current_state, deterministic=deterministic)
            for a in action:
                batch_actions.append(float(a))

            current_state = []        
    
    response = {
        "batch_actions": batch_actions
    }

    return response

def _submit_batch_replay(command_json):
    batch_replay = command_json["batch_replays"]
    
    for replay in batch_replay:
        state = replay["state"]
        action = replay["action"]
        reward = replay["reward"]
        state_ = replay["state_"]
        done = replay["done"]
        agent.replay_pool.push(Transition(state, action, reward, state_, done))
    
    response = {
        "done": True
    }

    return response

def _train(command_json):
    print_logs = command_json["print_logs"]
    steps = command_json["steps"]
    if "checkpoint" in command_json:
        checkpoint = command_json["checkpoint"]
        make_checkpoint(agent, checkpoint)
    q1_loss, q2_loss, pi_loss, a_loss = agent.optimize(steps)
    
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
    agent = Agent(
        state_dim=command_json["state_dim"], 
        action_dim=["action_dim"],
        batchsize=["batchsize"],
        hidden_size=["hidden_size"]
    )
    
    response = {
        "done": True
    }
    
    print("New Agent initialized")

    return response

def _load_agent(command_json):
    load_checkpoint(agent, command_json["step_count"])
    
    response = {
        "done": True
    }
    
    print("Agent loaded")

    return response