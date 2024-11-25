import itertools
import math
import os
import random
from collections import deque, namedtuple

import numpy as np
import torch
from moviepy.editor import ImageSequenceClip
from torch.distributions import constraints
from torch.distributions.transforms import Transform
from torch.nn.functional import softplus
import json

Transition = namedtuple('Transition', ('state', 'action', 'reward', 'nextstate', 'done'))


class MeanStdevFilter():
    def __init__(self, shape, clip=3.0):
        self.eps = 1e-4
        self.shape = shape
        self.clip = clip
        self._count = 0
        self._running_sum = np.zeros(shape)
        self._running_sum_sq = np.zeros(shape) + self.eps
        self.mean = np.zeros(shape)
        self.stdev = np.ones(shape) * self.eps

    def update(self, x):
        if len(x.shape) == 1:
            x = x.reshape(1,-1)
        self._running_sum += np.sum(x, axis=0)
        self._running_sum_sq += np.sum(np.square(x), axis=0)
        # assume 2D data
        self._count += x.shape[0]
        self.mean = self._running_sum / self._count
        self.stdev = np.sqrt(
            np.maximum(
                self._running_sum_sq / self._count - self.mean**2,
                 self.eps
                 ))
    
    def __call__(self, x):
        return np.clip(((x - self.mean) / self.stdev), -self.clip, self.clip)

    def invert(self, x):
        return (x * self.stdev) + self.mean


class ReplayPool:

    def __init__(self, capacity=1e6):
        self.capacity = int(capacity)
        self._memory = deque(maxlen=int(capacity))
        
    def push(self, transition: Transition):
        """ Saves a transition """
        self._memory.append(transition)
        
    def sample(self, batch_size: int) -> Transition:
        transitions = random.sample(self._memory, min(len(self._memory), batch_size))
        return Transition(*zip(*transitions))

    def get(self, start_idx: int, end_idx: int) -> Transition:
        transitions = list(itertools.islice(self._memory, start_idx, end_idx))
        return Transition(*zip(*transitions))

    def get_all(self) -> Transition:
        return self.get(0, len(self._memory))

    def __len__(self) -> int:
        return len(self._memory)

    def clear_pool(self):
        self._memory.clear()


# Taken from: https://github.com/pytorch/pytorch/pull/19785/files
# The composition of affine + sigmoid + affine transforms is unstable numerically
# tanh transform is (2 * sigmoid(2x) - 1)
# Old Code Below:
# transforms = [AffineTransform(loc=0, scale=2), SigmoidTransform(), AffineTransform(loc=-1, scale=2)]
class TanhTransform(Transform):
    r"""
    Transform via the mapping :math:`y = \tanh(x)`.
    It is equivalent to
    ```
    ComposeTransform([AffineTransform(0., 2.), SigmoidTransform(), AffineTransform(-1., 2.)])
    ```
    However this might not be numerically stable, thus it is recommended to use `TanhTransform`
    instead.
    Note that one should use `cache_size=1` when it comes to `NaN/Inf` values.
    """
    domain = constraints.real
    codomain = constraints.interval(-1.0, 1.0)
    bijective = True
    sign = +1

    @staticmethod
    def atanh(x):
        return 0.5 * (x.log1p() - (-x).log1p())

    def __eq__(self, other):
        return isinstance(other, TanhTransform)

    def _call(self, x):
        return x.tanh()

    def _inverse(self, y):
        # We do not clamp to the boundary here as it may degrade the performance of certain algorithms.
        # one should use `cache_size=1` instead
        return self.atanh(y)

    def log_abs_det_jacobian(self, x, y):
        # We use a formula that is more numerically stable, see details in the following link
        # https://github.com/tensorflow/probability/blob/master/tensorflow_probability/python/bijectors/tanh.py#L69-L80
        return 2. * (math.log(2.) - x - softplus(-2. * x))


def make_checkpoint(agent, step_count):
    q_funcs, target_q_funcs, policy, log_alpha = agent.q_funcs, agent.target_q_funcs, agent.policy, agent.log_alpha
    
    save_path = "checkpoints/model-{}.pt".format(step_count)

    if not os.path.isdir('checkpoints'):
        os.makedirs('checkpoints')

    torch.save({
        'double_q_state_dict': q_funcs.state_dict(),
        'target_double_q_state_dict': target_q_funcs.state_dict(),
        'policy_state_dict': policy.state_dict(),
        'log_alpha_state_dict': log_alpha
    }, save_path)
    
    print(f"checkpoint saved as: {save_path}")

def load_checkpoint(agent, step_count):
    print("Current working directory:", os.getcwd())
    load_path = "checkpoints/model-{}.pt".format(step_count)

    if not os.path.isfile(load_path):
        print("Checkpoint not loaded")
        return False

    checkpoint = torch.load(load_path)

    agent.q_funcs.load_state_dict(checkpoint['double_q_state_dict'])
    agent.target_q_funcs.load_state_dict(checkpoint['target_double_q_state_dict'])
    agent.policy.load_state_dict(checkpoint['policy_state_dict'])
    agent.log_alpha = checkpoint['log_alpha_state_dict']
    
    print(f"Checkpoint loaded successfully from {load_path}")
    return True

def write_policy(policy):
    write_path = "AIServerCommFiles/policy.json"
    
    # Create a dictionary to store the weights
    weights_dict = {}

    # Extract weights and biases from the model
    for name, param in policy.named_parameters():
        # Convert tensor to CPU and then to a list for JSON serialization
        weights_dict[name] = param.data.cpu().numpy().tolist()

    # Save the weights to a JSON file
    with open(write_path, "w") as json_file:
        json.dump(weights_dict, json_file)

def write_to_file(write_path, dict):
    with open(write_path, "w") as file:
        json.dump(dict, file)