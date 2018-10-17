script "Capitalistic Optimal Noms Script (Ultra Mega Edition)";
notify "soolar the second";

import <CONSUME/INFO.ash>
import <CONSUME/CONSTANTS.ash>
import <CONSUME/RECORDS.ash>
import <CONSUME/HELPERS.ash>

//=============================================================================
// TODO:
// * Consider drunki-bears (maybe)
// * Handle mojo filters
// * Handle chocolates
// * Handle pvp fite gen (mainly for shots of kardashian gin)
// * Improve item_price (compare to cost of making)
//=============================================================================

boolean useSeasoning = false;
boolean havePinkyRing = available_amount($item[mafia pinky ring]) > 0;
boolean haveTuxedoShirt = available_amount($item[tuxedo shirt]) > 0;
int mojoFiltersUseable = 3 - get_property("currentMojoFilters").to_int();

boolean firstPassComplete = false;
boolean consumablesEvaluated = false;

int stomache_value(int space);
int liver_value(int space);
int spleen_value(int space);

Consumable [int] food;
Consumable [int] booze;
Consumable [int] spleenies;

// get the number of adventures from the consumable as it is configured
Range get_adventures(Consumable c)
{
	Range advs = c.it.get_adventures();
	if(c.organ == ORGAN_STOMACHE)
	{
		if(c.useForkMug)
			advs.multiply_round_up(c.it.is_salad() ? 1.5 : 1.3);
		if(useSeasoning)
			advs.add(1);
		advs.add(c.space); // account for milk
	}
	else if(c.organ == ORGAN_LIVER)
	{
		if(c.useForkMug)
			advs.multiply_round_up(is_beer(c.it) ? 1.5 : 1.3);
		if(havePinkyRing && c.it.is_wine())
			advs.multiply_round_nearest(1.125);
		if(haveTuxedoShirt && c.it.is_martini())
			advs.add(new Range(1, 3));
		advs.add(c.space); // account for ode
	}
	return advs;
}

float get_value(Consumable c)
{
	item forkMug = c.get_fork_mug();
	Range advs = c.get_adventures();
	float value = advs.average() * ADV_VALUE - c.it.item_price();
	if(c.useForkMug)
		value -= forkMug.item_price();

	if(firstPassComplete)
	{
		foreach i,oc in c.cleanings
		{
			switch(oc.organ)
			{
				case ORGAN_STOMACHE: value += stomache_value(oc.space); break;
				case ORGAN_LIVER: value += liver_value(oc.space); break;
				case ORGAN_SPLEEN: value += spleen_value(oc.space); break;
				default: print("Something bad happened."); break;
			}
		}
	}

	return value;
}

void evaluate_special_items()
{
	if($item[special seasoning].item_price() < ADV_VALUE)
		useSeasoning = true;
	else
		useSeasoning = false;
}

void evaluate_consumable(Consumable c)
{
	item forkMug = c.get_fork_mug();
	if(forkMug != $item[none])
	{
		boolean forkMugBonus = (forkMug == $item[ol' scratch's salad fork]) ?
			c.it.is_salad() : c.it.is_beer();
		float forkMugMult = forkMugBonus ? 0.5 : 0.3;
		Range forkMugAdvs = c.it.get_adventures();
		forkMugAdvs.multiply_round_up(forkMugMult);
		float forkMugValue = forkMugAdvs.average() * ADV_VALUE - forkMug.item_price();
		if(forkMugValue > 0)
			c.useForkMug = true;
	}

	record OrganMatcher
	{
		matcher m;
		int organ;
	};
	OrganMatcher [int] organMatchers =
	{
		new OrganMatcher(create_matcher("-(\\d+) Fullness", c.it.notes), ORGAN_STOMACHE),
		new OrganMatcher(create_matcher("-(\\d+) Drunkesnness", c.it.notes), ORGAN_LIVER),
		new OrganMatcher(create_matcher("-(\\d+) spleen", c.it.notes), ORGAN_SPLEEN),
	};
	foreach i,om in organMatchers
	{
		if(om.m.find())
		{
			int space = om.m.group(1).to_int();
			c.cleanings[c.cleanings.count()] = new OrganCleaning(om.organ, space);
		}
	}
}

void evaluate_consumables()
{
	clear(food);
	clear(booze);
	clear(spleenies);
	boolean [item] lookups;
	// can't directly assign this to lookups or it becomes a constant
	foreach it in $items[frosty's frosty mug, ol' scratch's salad fork,
		special seasoning, mojo filter, fudge spork, essential tofu,
		milk of magnesium]
		lookups[it] = true;
	int lookup_count = 0;
	foreach it in $items[]
	{
		if(it.tradeable.to_boolean() == false || it == $item[Jeppson's Malort])
			continue;

		Consumable c;
		c.it = it;
		c.space = 0;
		if(it.fullness > 0 && it.inebriety == 0)
		{
			c.space = it.fullness;
			c.organ = ORGAN_STOMACHE;
		}
		else if(it.inebriety > 0 && it.fullness == 0)
		{
			c.space = it.inebriety;
			c.organ = ORGAN_LIVER;
		}
		else if(it.spleen > 0)
		{
			c.space = it.spleen;
			c.organ = ORGAN_SPLEEN;
		}

		if(c.space == 0)
			continue;

		float advs_per_space = c.get_adventures().average() / c.space;
		if((c.organ == ORGAN_STOMACHE && advs_per_space >= 5) || // 5 for food idk
			(c.organ == ORGAN_LIVER && advs_per_space >= 6) || // 6 for liver because elemental caipiroska
			(c.organ == ORGAN_SPLEEN && advs_per_space > 0)) // anything for spleen
		{
			lookups[it] = true;
			lookup_count++;
			switch(c.organ)
			{
				case ORGAN_STOMACHE: food[food.count()] = c; break;
				case ORGAN_LIVER: booze[booze.count()] = c; break;
				case ORGAN_SPLEEN: spleenies[spleenies.count()] = c; break;
				default: print("Consumable with no organ specified?");
			}
		}
	}
	print("Looking up the price of " + lookup_count + " items");
	mall_prices(lookups);

	evaluate_special_items();

	foreach i,c in food
		evaluate_consumable(c);
	foreach i,c in booze
		evaluate_consumable(c);
	foreach i,c in spleenies
		evaluate_consumable(c);
	
	sort food by -value.get_value() / value.space;
	sort booze by -value.get_value() / value.space;
	sort spleenies by -value.get_value() / value.space;

	// now get_value will try to account for cleared out organ space
	firstPassComplete = true;

	sort food by -value.get_value() / value.space;
	sort booze by -value.get_value() / value.space;
	sort spleenies by -value.get_value() / value.space;

	void print_some(Consumable [int] list)
	{
		for(int i = 0; i < 5; ++i)
		{
			Consumable c = list[i];
			buffer b;
			b.append(i);
			b.append(": ");
			b.append(c.it.to_string());
			if(c.useForkMug)
			{
				switch(c.organ)
				{
					case ORGAN_STOMACHE: b.append(" (w/fork)"); break;
					case ORGAN_LIVER: b.append(" (w/mug)"); break;
					default: b.append(" (useForkMug true but not food/booze...)"); break;
				}
			}
			b.append(" (");
			b.append(c.get_value() / c.space);
			b.append(")");
			print(b.to_string());
		}
	}
	/*
	print("food" + (useSeasoning ? " (use special seasoning)" : ""));
	print_some(food);
	print("booze");
	print_some(booze);
	print("spleenies");
	print_some(spleenies);
	*/

	consumablesEvaluated = true;
}

void evaluate_consumables_if_needed()
{
	if(!consumablesEvaluated)
		evaluate_consumables();
}

int space_value(Consumable [int] list, int space)
{
	if(space <= 0)
		return 0;

	float value = 0;

	foreach i,c in list
	{
		// assume the list is sorted already
		if(c.space <= space)
		{
			int amount = floor(space / c.space);
			value += c.get_value() * amount;
			space -= c.space * amount;
			if(space <= 0)
				break;
		}
	}

	return value;
}

int stomache_value(int space)
{
	return space_value(food, space);
}

int liver_value(int space)
{
	return space_value(booze, space);
}

int spleen_value(int space)
{
	return space_value(spleenies, space);
}

int organ_value(int stomache, int liver, int spleen)
{
	return stomache_value(stomache) + liver_value(liver) + spleen_value(spleen);
}

Consumable best_consumable(Consumable [int] list, int space)
{
	//evaluate_consumables_if_needed();
	foreach i,c in list
	{
		if(c.space <= space)
			return c;
	}

	Consumable nothing;
	return nothing;
}

Consumable best_spleen(int space)
{
	Consumable res = best_consumable(spleenies, space);
	if(res.it == $item[none])
		print("Failed to find spleenie of size " + space + "!", "red");
	return res;
}

Consumable best_stomache(int space)
{
	Consumable res = best_consumable(food, space);
	if(res.it == $item[none])
		print("Failed to find food of size " + space + "!", "red");
	return res;
}

Consumable best_liver(int space)
{
	Consumable res = best_consumable(booze, space);
	if(res.it == $item[none])
		print("Failed to find booze of size " + space + "!", "red");
	return res;
}

void handle_organ_cleanings(Consumable [int] diet, Consumable c, OrganSpace space);

void fill_spleen(Consumable [int] diet, OrganSpace space)
{
	while(space.spleen > 0)
	{
		Consumable best = best_spleen(space.spleen);
		if(best.it == $item[none])
			break;
		space.spleen -= best.space;
		diet[diet.count()] = best;
	}
	if(space.spleen > 0)
		print("Failed to fully fill spleen! " + space.spleen + " left...", "red");
}

void fill_stomache(Consumable [int] diet, OrganSpace space)
{
	while(space.fullness > 0)
	{
		Consumable best = best_stomache(space.fullness);
		if(best.it == $item[none])
			break;
		handle_organ_cleanings(diet, best, space);
		space.fullness -= best.space;
		diet[diet.count()] = best;
	}
	if(space.fullness > 0)
		print("Failed to fully fill stomache! " + space.fullness + " left...", "red");
}

void fill_liver(Consumable [int] diet, OrganSpace space)
{
	while(space.inebriety > 0)
	{
		Consumable best = best_liver(space.inebriety);
		if(best.it == $item[none])
			break;
		handle_organ_cleanings(diet, best, space);
		space.inebriety -= best.space;
		diet[diet.count()] = best;
	}
	if(space.inebriety > 0)
		print("Failed to fully fill liver! " + space.inebriety + " left...", "red");
}

void handle_organ_cleanings(Consumable [int] diet, Consumable c, OrganSpace space)
{
	foreach i,oc in c.cleanings
	{
		switch(oc.organ)
		{
			case ORGAN_SPLEEN:
				if(space.spleen + oc.space > space.spleen_limit)
					fill_spleen(diet, space);
				space.spleen += oc.space;
				break;
			case ORGAN_STOMACHE:
				if(space.fullness + oc.space > space.fullness_limit)
					fill_stomache(diet, space);
				space.fullness += oc.space;
				break;
		}
	}
}

Consumable [int] get_diet(OrganSpace space)
{
	evaluate_consumables_if_needed();

	Consumable [int] diet;

	while(space.fullness + space.inebriety + space.spleen > 0)
	{
		if(space.spleen > 0)
		{
			fill_spleen(diet, space);
			if(space.spleen > 0)
			 break;
		}
		if(space.fullness > 0)
		{
			fill_stomache(diet, space);
			if(space.fullness > 0)
				break;
		}
		if(space.inebriety > 0)
		{
			fill_liver(diet, space);
			if(space.inebriety > 0)
				break;
		}
	}

	return diet;
}

Consumable [int] get_diet(int stom, int liv, int sple)
{
	return get_diet(make_organ_space(stom, liv, sple));
}

void print_diet(Consumable [int] diet)
{
	buffer b;
	b.append("Your ideal diet: ");
	foreach i,c in diet
	{
		if(c.useForkMug)
		{
			item forkMug = c.get_fork_mug();
			if(forkMug == $item[ol' scratch's salad fork])
				b.append("eat ");
			else
				b.append("drink ");
			b.append(forkMug.to_string());
			b.append("; ");
		}
		switch(c.organ)
		{
			case ORGAN_SPLEEN: b.append("chew "); break;
			case ORGAN_STOMACHE: b.append("eat "); break;
			case ORGAN_LIVER: b.append("drink "); break;
			default: b.append("wtf "); break;
		}
		b.append(c.it.to_string());
		b.append("; ");
	}
	print(b.to_string());
}

void main()
{
	evaluate_consumables();
	print("value of 15 stomache: " + stomache_value(15));
	print("value of 21 liver: " + liver_value(21));
	print("value of 15 spleen: " + spleen_value(15));

	print_diet(get_diet(15, 21, 15));
}