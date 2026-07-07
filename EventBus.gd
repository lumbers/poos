extends Node

# These are global announcements the game will shout out!
signal card_played(card_node)
signal cards_discarded(amount)
signal pie_took_damage(pie_node, damage_amount)
signal turn_ended()
