package com.sporthenon.db.entity;

import java.sql.Timestamp;
import java.util.Map;

import com.sporthenon.db.entity.meta.Metadata;

public class Team extends AbstractEntity {

	private Integer id;
	private String label;
	private Sport sport;
	private String year1;
	private String year2;
	private Country country;
	private League league;
	private String conference;
	private String division;
	private String comment;
	private Integer link;
	private Boolean inactive;
	private Integer ref;
	private Boolean nopic;
	
	public static final transient String alias = "TM";
	public static final transient String table = "team";
	public static final transient String key =   "id";
	
	public Team() {}
	
	public Team(Integer id) {
		this.id = id;
	}
	
	public void setValuesFromMap(Map<String, Object> mapValues) {
		if (mapValues != null) {
			setId((Integer)mapValues.get("id"));
			setLabel((String)mapValues.get("label"));
			Integer idSport = (Integer)mapValues.get("id_sport");
			if (idSport != null) {
				setSport(new Sport(idSport));	
			}
			setYear1((String)mapValues.get("year1"));
			setYear2((String)mapValues.get("year2"));
			Integer idCountry = (Integer)mapValues.get("id_country");
			if (idCountry != null) {
				setCountry(new Country(idCountry));	
			}
			Integer idLeague = (Integer)mapValues.get("id_league");
			if (idLeague != null) {
				setLeague(new League(idLeague));	
			}
			setConference((String)mapValues.get("conference"));
			setDivision((String)mapValues.get("division"));
			setDivision((String)mapValues.get("division"));
			setComment((String)mapValues.get("comment"));
			setLink((Integer)mapValues.get("link"));
			setInactive((Boolean)mapValues.get("inactive"));
			setRef((Integer)mapValues.get("ref"));
			setNopic((Boolean)mapValues.get("no_pic"));
			setMetadata(new Metadata((Integer)mapValues.get("id_contributor"), (Timestamp)mapValues.get("first_update"), (Timestamp)mapValues.get("last_update")));
		}
	}
	
	public Integer getId() {
		return id;
	}

	public void setId(Integer id) {
		this.id = id;
	}

	public String getLabel() {
		return label;
	}

	public void setLabel(String label) {
		this.label = label;
	}

	public Sport getSport() {
		return sport;
	}

	public void setSport(Sport sport) {
		this.sport = sport;
	}

	public String getYear1() {
		return year1;
	}

	public void setYear1(String year1) {
		this.year1 = year1;
	}

	public String getYear2() {
		return year2;
	}

	public void setYear2(String year2) {
		this.year2 = year2;
	}

	public Country getCountry() {
		return country;
	}

	public void setCountry(Country country) {
		this.country = country;
	}

	public String getConference() {
		return conference;
	}

	public void setConference(String conference) {
		this.conference = conference;
	}

	public String getDivision() {
		return division;
	}

	public void setDivision(String division) {
		this.division = division;
	}

	public String getComment() {
		return comment;
	}

	public void setComment(String comment) {
		this.comment = comment;
	}

	public Integer getLink() {
		return link;
	}

	public Boolean getInactive() {
		return inactive;
	}

	public void setLink(Integer link) {
		this.link = link;
	}

	public void setInactive(Boolean inactive) {
		this.inactive = inactive;
	}

	public Integer getRef() {
		return ref;
	}

	public void setRef(Integer ref) {
		this.ref = ref;
	}

	public League getLeague() {
		return league;
	}

	public void setLeague(League league) {
		this.league = league;
	}
	
	public Boolean getNopic() {
		return nopic;
	}

	public void setNopic(Boolean nopic) {
		this.nopic = nopic;
	}

	@Override
	public String toString() {
		return label + (country != null ? ", " + country : "") + (sport != null ? ", " + sport.getLabel() : "") + " [#" + id + "]";
	}
	
	public String toString2() {
		return label + (country != null ? " (" + country.getCode() + ")" : "");
	}
	
}