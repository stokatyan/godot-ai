extends RefCounted

class_name PolicyAgent

var _nn: NeuralNetwork

func _init(nn: NeuralNetwork):
	_nn = nn

# Clamp function
func _clamp(value: float, min_val: float, max_val: float) -> float:
	return max(min(value, max_val), min_val)

# Exponential function
func _exp(value: float) -> float:
	return pow(2.718281828459045, value)

# Forward function (replicates your PyTorch policy logic)
func get_action(x: Array[float], is_deterministic: bool = false) -> Array[float]:
	var mu_logstd = _nn.feed_forward(x)
	var mu = mu_logstd.slice(0, mu_logstd.size() / 2)

	if !is_deterministic:
		var logstd = mu_logstd.slice(mu_logstd.size() / 2, mu_logstd.size())

		# Clamp logstd
		for i in range(logstd.size()):
			logstd[i] = _clamp(logstd[i], -20, 2)

		# Calculate standard deviation
		var std = logstd.map(_exp)

		# Create a normal distribution (mean = mu, std = std)
		var action: Array[float] = []
		for i in range(mu.size()):
			action.append(mu[i] + randf() * std[i])  # Simplified rsample

		# Tanh transform
		for i in range(action.size()):
			action[i] = tanh(action[i])

		return action
	else:
		# Calculate mean (tanh(mu))
		for i in range(mu.size()):
			mu[i] = tanh(mu[i])

		return mu
