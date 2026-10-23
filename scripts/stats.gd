extends VBoxContainer
class_name Stats


func set_steps(steps: int) -> void:
	$StepCounter.text = "Steps: %s" % steps
	
	
func set_arrows(arrows: int) -> void:
	$ArrowCounter.text = "Arrows: %s" % arrows
