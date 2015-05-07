package com.sporthenon.updater.container.entity;

import javax.swing.JCheckBox;
import javax.swing.JLabel;
import javax.swing.JTextField;

import com.sporthenon.db.entity.Country;
import com.sporthenon.db.entity.Sport;
import com.sporthenon.updater.component.JCustomTextField;
import com.sporthenon.updater.component.JEntityPicklist;
import com.sporthenon.utils.SwingUtils;

public class JTeamPanel extends JAbstractEntityPanel {

	private static final long serialVersionUID = 1L;
	
	public JCustomTextField jLabel;
	public JEntityPicklist jSport;
	public JEntityPicklist jCountry;
	public JTextField jConference;
	public JTextField jDivision;
	public JTextField jComment;
	public JTextField jYear1;
	public JTextField jYear2;
	public JLabel lLink;
	public JTextField jLink;
	public JCheckBox jInactive;
	
	public JTeamPanel() {
		super(12);
		initialize();
	}

	protected void initialize() {
        //Name
        JLabel lLabel = new JLabel(" Name:");
        lLabel.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lLabel);
        jLabel = new JCustomTextField();
        jLabel.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jLabel);
        
        //Sport
        JLabel lSport = new JLabel(" Sport:");
        lSport.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lSport);
        jSport = new JEntityPicklist(null, Sport.alias);
        gridPanel.add(jSport);
        
        //Country
        JLabel lCountry = new JLabel(" Country:");
        lCountry.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lCountry);
        jCountry = new JEntityPicklist(null, Country.alias);
        gridPanel.add(jCountry);
        
        //Comment
        JLabel lComment = new JLabel(" Comment:");
        lComment.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lComment);
        jComment = new JTextField();
        jComment.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jComment);
        
		//Link
        lLink = new JLabel(" Link:");
		lLink.setHorizontalAlignment(LABEL_ALIGNMENT);
		gridPanel.add(lLink);
		jLink = new JTextField();
		jLink.setPreferredSize(TEXT_SIZE);
		gridPanel.add(jLink);
        
        //Inactive
        JLabel lInactive = new JLabel(" Inactive:");
        lInactive.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lInactive);
        jInactive = new JCheckBox();
        gridPanel.add(jInactive);
        
        //Conference
        JLabel lConference = new JLabel(" [US] Conference:");
        lConference.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lConference);
        jConference = new JTextField();
        jConference.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jConference);
        
        //Division
        JLabel lDivision = new JLabel(" [US] Division:");
        lDivision.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lDivision);
        jDivision = new JTextField();
        jDivision.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jDivision);
        
        //Year1
        JLabel lYear1 = new JLabel(" [US] From:");
        lYear1.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lYear1);
        jYear1 = new JTextField();
        jYear1.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jYear1);
        
        //Year2
        JLabel lYear2 = new JLabel(" [US] To:");
        lYear2.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lYear2);
        jYear2 = new JTextField();
        jYear2.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jYear2);
	}

	public JCustomTextField getLabel() {
		return jLabel;
	}

	public JEntityPicklist getSport() {
		return jSport;
	}

	public JEntityPicklist getCountry() {
		return jCountry;
	}

	public JTextField getConference() {
		return jConference;
	}

	public JTextField getDivision() {
		return jDivision;
	}
	
	public JTextField getLink() {
		return jLink;
	}

	public JCheckBox getInactive() {
		return jInactive;
	}

	public JTextField getComment() {
		return jComment;
	}

	public JTextField getYear1() {
		return jYear1;
	}

	public JTextField getYear2() {
		return jYear2;
	}
	
	public void setLabel(String s) {
		jLabel.setText(s);
	}

	public void setSport(Integer id) {
		SwingUtils.selectValue(jSport, id);
	}

	public void setCountry(Integer id) {
		SwingUtils.selectValue(jCountry, id);
	}

	public void setConference(String s) {
		jConference.setText(s);
	}

	public void setDivision(String s) {
		jDivision.setText(s);
	}
	
	public void setLink(String s) {
		jLink.setText(s);
	}
	
	public void setLinkLabel(String s) {
		lLink.setText(s);
	}

	public void setInactive(Boolean b) {
		jInactive.setSelected(b != null && b);
	}

	public void setComment(String s) {
		jComment.setText(s);
	}

	public void setYear1(String s) {
		jYear1.setText(s);;
	}

	public void setYear2(String s) {
		jYear2.setText(s);
	}

	public void clear() {
		jId.setText("");
		jLabel.setText("");
		jSport.clear();
		jCountry.clear();
		jConference.setText("");
		jLink.setText("");
		jInactive.setSelected(false);
		jDivision.setText("");
		jComment.setText("");
		jYear1.setText("");
		jYear2.setText("");
	}
	
	public void focus() {
		jLabel.focus();
	}
	
}